# Hướng dẫn hoàn thành Lab Day 26 — Function Calling, MCP và Google ADK

Tài liệu này giải thích toàn bộ cấu trúc của repository, mối liên hệ giữa các phần `01`–`04`, và chia công việc thành các checkpoint có tiêu chí hoàn thành rõ ràng. Các lệnh chính được viết cho **Windows PowerShell**, đúng với môi trường của repository hiện tại.

> Phạm vi bắt buộc để hoàn thành sản phẩm cuối là `04-lab`. Ba thư mục `01-function-calling`, `02-mcp-basics` và `03-production` là lộ trình nền tảng giúp hiểu vì sao Lab 04 được thiết kế như hiện tại.

## 1. Kết quả cuối cùng cần đạt

Sau khi hoàn thành lab, hệ thống phải chạy được theo luồng:

```text
Người dùng
   │ chat tại http://localhost:8000
   ▼
Google ADK Web + weather_agent
   │ Gemini chọn tool bằng Function Calling
   │ MCP Streamable HTTP: http://localhost:8085/mcp
   ▼
Weather MCP Server
   │ REST/HTTPS
   ▼
WeatherAPI.com
```

Người dùng có thể hỏi thời tiết bằng ngôn ngữ tự nhiên. Gemini không tự truy cập WeatherAPI; nó chọn một MCP tool, ADK gọi tool qua MCP, server gọi WeatherAPI, rồi Gemini tổng hợp dữ liệu thành câu trả lời.

Ba tool server công bố:

| Tool | Đầu vào | Chức năng |
|---|---|---|
| `get_current_weather` | `city: str` | Lấy thời tiết hiện tại |
| `get_forecast` | `city: str`, `days: int = 3` | Lấy dự báo, tối đa 3 ngày trong code hiện tại |
| `health_check` | Không có | Xác nhận tiến trình MCP server đang hoạt động |

## 2. Ý tưởng chính của bài lab

### 2.1 Function Calling và MCP không thay thế nhau

- **Function Calling** là khả năng của model: model quyết định cần gọi hàm nào và sinh tham số phù hợp.
- **MCP** là giao thức giữa client và server: client khám phá tool, gọi tool và nhận kết quả theo một chuẩn chung.
- **Google ADK** là lớp điều phối: nhận câu hỏi, đưa danh sách MCP tool cho Gemini, thực hiện lời gọi tool và gửi kết quả lại cho Gemini.

Trong Lab 04:

```text
Gemini       → quyết định gọi get_forecast(city="Hanoi", days=3)
Google ADK   → điều phối vòng lặp Function Calling
McpToolset   → chuyển lời gọi sang giao thức MCP
MCP Server   → thực thi get_forecast
WeatherAPI   → cung cấp dữ liệu thật
```

### 2.2 Luồng một request hoàn chỉnh

Ví dụ người dùng hỏi: “Cho tôi dự báo 3 ngày ở Đà Nẵng”.

1. ADK nhận prompt từ giao diện web.
2. `McpToolset` khám phá schema tool từ MCP server.
3. Gemini chọn `get_forecast` và sinh `{"city": "Da Nang", "days": 3}`.
4. ADK gửi `call_tool` tới `http://localhost:8085/mcp`.
5. MCP server gọi endpoint `forecast.json` của WeatherAPI.
6. Server định dạng dữ liệu thành chuỗi và trả về qua MCP.
7. ADK chuyển kết quả tool cho Gemini.
8. Gemini viết câu trả lời cuối cho người dùng.

## 3. Bản đồ toàn bộ repository

### 3.1 Thư mục gốc

| File/thư mục | Vai trò |
|---|---|
| `README.md` | So sánh Function Calling và MCP, mô tả lộ trình toàn repo |
| `requirements.txt` | Môi trường dùng cho phần `01`–`03`; yêu cầu MCP SDK v2 |
| `.gitignore` | Loại trừ virtual environment, `.env`, cache Python, DB và `.DS_Store` |
| `01-function-calling/` | Function Calling thuần với Gemini SDK |
| `02-mcp-basics/` | MCP server/client tối giản qua `stdio` |
| `03-production/` | Auth, tool registry và versioning |
| `04-lab/` | Sản phẩm chính: ADK agent + remote MCP server + WeatherAPI |

### 3.2 `01-function-calling`

`weather_function_calling.py` chứa cả bốn trách nhiệm trong cùng một ứng dụng:

1. Viết schema `get_weather` bằng `types.FunctionDeclaration`.
2. Cài đặt hàm `get_weather` với dữ liệu mock.
3. Gọi model lấy từ `GEMINI_MODEL`, mặc định `gemini-3.5-flash-lite`.
4. Tự xử lý vòng lặp: nhận `function_calls`, chạy hàm, gửi kết quả lại model.

Phần này chứng minh model chỉ **yêu cầu** gọi hàm; ứng dụng mới là nơi thực thi hàm.

### 3.3 `02-mcp-basics`

- `weather_server.py` dùng `MCPServer` và `@mcp.tool()` để công bố `get_weather`.
- Type hint và docstring được dùng để tạo schema tự động.
- `weather_client.py` tự khởi động server con qua `stdio`, gọi `list_tools()`, sau đó gọi `call_tool()` cho ba thành phố.

Khác biệt so với phần 01: tool được tách khỏi app và client khám phá tool ở runtime.

### 3.4 `03-production`

| Nhóm | File | Điều được minh họa |
|---|---|---|
| Authentication | `auth_server.py`, `auth_client.py` | Streamable HTTP và Bearer token |
| Discovery | `registry.json`, `registry_client.py` | Tìm tool theo tag/keyword và chọn semantic version cao nhất |
| Versioning | `versioned_server.py`, `versioned_client.py` | Giữ v1, thêm v2 và công bố metadata `server://info` |

Các ví dụ production vẫn dùng dữ liệu mock. Chúng minh họa kiến trúc, chưa phải một hệ thống production đầy đủ: token tĩnh, registry bằng JSON, chưa có retry, tracing, rate limit hoặc secret manager.

### 3.5 `04-lab/mcp-server`

#### `weather.py`

- Đọc `PORT`, mặc định là `8085`.
- Đọc `WEATHERAPI_KEY` một lần khi module được import.
- Tạo `FastMCP("weather")` lắng nghe trên `0.0.0.0`.
- `make_weather_request()` gọi WeatherAPI bằng `httpx.AsyncClient`, timeout 30 giây và xử lý lỗi HTTP/network.
- `get_current_weather()` gọi `current.json`.
- `get_forecast()` gọi `forecast.json` và giới hạn `days` tối đa là 3.
- `health_check()` chỉ kiểm tra MCP server; tool này không xác minh WeatherAPI key.
- Khi có biến `PORT` hoặc chạy trong terminal tương tác, server dùng `streamable-http`; trường hợp còn lại có thể rơi về `stdio`.

#### `pyproject.toml` và `uv.lock`

- Project cho phép Python `>=3.10`.
- `pyproject.toml` dùng giới hạn tối thiểu; `uv.lock` khóa toàn bộ dependency để chạy lặp lại được.
- Lock hiện tại chốt các thành phần chính như MCP, FastMCP, HTTPX, Uvicorn và Starlette.

#### `Dockerfile`

- Dùng `python:3.12-slim`.
- Cài dependency từ `pyproject.toml`.
- Copy `weather.py`, expose cổng `8080`, rồi chạy `python weather.py`.
- Cloud Run sẽ cung cấp biến `PORT`; khi chạy Docker local cần đặt `PORT=8080` rõ ràng.

### 3.6 `04-lab/mcp-client`

#### `weather_agent/agent.py`

- Đọc `MCP_SERVER_URL`, mặc định `http://localhost:8085/mcp`.
- Tạo `StreamableHTTPConnectionParams` với timeout 30 giây.
- Bọc kết nối trong `McpToolset`.
- Gắn toolset vào `Agent(name="weather_agent", model=GEMINI_MODEL)`.
- Nếu khởi tạo đối tượng thất bại, code tạo agent fallback không có tool.

Lưu ý: log “MCP toolset configured” chưa chứng minh đã gọi tool thành công vì kết nối được thiết lập ở lần dùng đầu tiên. CP7 xác minh MCP handshake; bài test end-to-end ở CP8 mới chứng minh cả Gemini và WeatherAPI hoạt động.

#### `verify_setup.py`

Script kiểm tra năm nhóm:

1. `.env` và `GOOGLE_API_KEY`.
2. Dependency Python.
3. Cấu trúc package `weather_agent`.
4. MCP handshake, discovery đủ ba tool và gọi `health_check`.
5. Import được `root_agent`.

Script dùng MCP client thật thay vì suy luận từ một HTTP GET thông thường, nên checkpoint verification xác nhận được cả `initialize`, `list_tools` và `health_check`.

#### `pyproject.toml` và `uv.lock`

- Client yêu cầu Python `>=3.12`.
- Dependency chính: Google ADK, Google GenAI, MCP, FastMCP, python-dotenv và HTTPX.
- Server và client có lock file riêng; không nên gộp hai môi trường với môi trường `requirements.txt` ở root.

## 4. Điều kiện trước khi bắt đầu

### 4.1 Công cụ

- Git.
- `uv`.
- Python 3.12 trở lên, vì client yêu cầu `>=3.12`.
- Trình duyệt để dùng ADK Web.
- Docker chỉ cần cho checkpoint Docker.

Kiểm tra:

```powershell
git --version
uv --version
uv python list --only-installed
```

Nếu chưa có Python 3.12 do `uv` quản lý:

```powershell
uv python install 3.12
```

Tại thời điểm khảo sát repository ngày 14/10/2026, máy hiện tại có `uv 0.12.21`, lệnh `python` chưa nằm trên `PATH`, và `uv` chỉ nhìn thấy Python 3.11. Vì vậy cần cài/chọn Python 3.12 trước khi đồng bộ `mcp-client`. Các lệnh `uv run` bên dưới giúp tránh phụ thuộc vào lệnh `python` toàn cục.

### 4.2 API key

Cần hai key khác nhau:

| Key | Dùng ở đâu | Mục đích |
|---|---|---|
| `WEATHERAPI_KEY` | Process của MCP server | Gọi WeatherAPI.com |
| `GOOGLE_API_KEY` | `.env` của MCP client | Gọi Gemini qua Google ADK |

Không ghi key thật vào code, README, ảnh chụp hoặc commit. `.gitignore` đã loại `.env`, nhưng vẫn phải kiểm tra `git status` trước khi nộp.

### 4.3 Ba môi trường dependency tách biệt

```text
Môi trường A: root/.venv                 → phần 01–03
Môi trường B: 04-lab/mcp-server/.venv   → Weather MCP server
Môi trường C: 04-lab/mcp-client/.venv   → Google ADK client
```

Việc tách này quan trọng vì root yêu cầu MCP SDK v2, còn hai project trong Lab 04 có lock file riêng.

## 5. Bảng checkpoint tổng quan

| Checkpoint | Nội dung | Mức độ | Bằng chứng hoàn thành |
|---|---|---|---|
| CP0 | Chuẩn bị công cụ, Python và key | Bắt buộc | Python 3.12, `uv`, hai key sẵn sàng |
| CP1 | Chạy Function Calling thuần | Nền tảng | Thấy model yêu cầu và app thực thi tool |
| CP2 | Chạy MCP cơ bản qua stdio | Nền tảng | `list_tools` và ba kết quả thời tiết mock |
| CP3 | Chạy ba mẫu production | Nền tảng nâng cao | Auth, registry, versioning đều hoạt động |
| CP4 | Cài và chạy Weather MCP server | Bắt buộc | Server lắng nghe tại `:8085/mcp` |
| CP5 | Kiểm tra reachability và cấu hình server | Bắt buộc | Endpoint phản hồi, log đúng transport |
| CP6 | Cài và cấu hình ADK client | Bắt buộc | `.env` đúng, import agent thành công |
| CP7 | Chạy script verification | Bắt buộc | Năm nhóm kiểm tra đều pass |
| CP8 | Test end-to-end trên ADK Web | Bắt buộc | Current weather, forecast và health đều gọi tool thật |
| CP9 | Đóng gói và chạy Docker | Tùy yêu cầu | Container phục vụ MCP tại cổng local 8085 |
| CP10 | Hoàn thiện minh chứng và bàn giao | Bắt buộc | Không lộ secret, có checklist/test evidence |

### Trạng thái thực thi ngày 14/10/2026

| Checkpoint | Trạng thái | Kết quả đã xác minh |
|---|---|---|
| CP0 | ✅ Hoàn thành | Python 3.12.14; ba môi trường dependency đã đồng bộ |
| CP1 | ✅ Hoàn thành | Function Calling gọi tool cho Hà Nội và Đà Nẵng bằng `gemini-3.5-flash-lite` |
| CP2 | ✅ Hoàn thành | MCP stdio khám phá và gọi `get_weather` cho ba thành phố |
| CP3 | ✅ Hoàn thành | Auth HTTP, registry và versioning đều chạy thành công |
| CP4 | ✅ Hoàn thành | Weather MCP server chạy Streamable HTTP tại cổng 8085 |
| CP5 | ✅ Hoàn thành | Endpoint phản hồi; discovery đủ ba tool; WeatherAPI trả dữ liệu thật |
| CP6 | ✅ Hoàn thành | ADK client đồng bộ, `.env` được Git ignore |
| CP7 | ✅ Hoàn thành | Verification pass; MCP handshake và `health_check` thành công |
| CP8 | ✅ Hoàn thành | ADK gọi đủ health/current/forecast; Web UI trả HTTP 200 |
| CP9 | ⏭️ Tùy chọn | Chưa chạy vì Docker Engine trên máy chưa được khởi động |
| CP10 | ⚠️ Gần hoàn thành | Syntax, lock, whitespace và secret scan pass; cần xoay vòng WeatherAPI key từng xuất hiện trong log cũ |

## 6. Hướng dẫn chi tiết từng checkpoint

### CP0 — Chuẩn bị môi trường

**Mục tiêu:** bảo đảm các checkpoint sau không lỗi vì sai thư mục, sai Python hoặc thiếu key.

1. Đi tới root repository:

   ```powershell
   Set-Location "D:\LAB_VIN\Lab_day26\KX-DAY26-VuVanDien-2A202602418"
   ```

2. Kiểm tra trạng thái Git trước khi làm:

   ```powershell
   git status --short
   ```

3. Cài/chọn Python 3.12:

   ```powershell
   uv python install 3.12
   uv python find 3.12
   ```

4. Chuẩn bị hai API key nhưng chưa ghi chúng vào source.

5. Tạo môi trường cho phần `01`–`03` nếu muốn học đủ lộ trình:

   ```powershell
   uv venv --python 3.12 .venv
   uv pip install --python .\.venv\Scripts\python.exe -r requirements.txt
   ```

**Hoàn thành khi:** `uv python find 3.12` trả về interpreter, hai key đã có, và môi trường root cài được dependency nếu sẽ chạy CP1–CP3.

**Lỗi thường gặp:**

- `python is not recognized`: dùng `uv run`, hoặc gọi interpreter trong `.venv` thay vì trông chờ `python` trên `PATH`.
- PowerShell chặn `Activate.ps1`: không cần activate; dùng trực tiếp `.\.venv\Scripts\python.exe`.
- Cài tất cả dependency vào một venv: xóa bỏ thói quen này; Lab 04 đã có hai `uv.lock` riêng.

---

### CP1 — Hiểu và chạy Function Calling thuần

**Mục tiêu:** nhìn thấy rõ model yêu cầu gọi tool nhưng app mới là nơi chạy hàm.

1. Đặt key cho terminal hiện tại:

   ```powershell
   $env:GEMINI_API_KEY = "<GEMINI_API_KEY_CUA_BAN>"
   ```

2. Chạy ví dụ bằng môi trường root:

   ```powershell
   Set-Location .\01-function-calling
   & ..\.venv\Scripts\python.exe .\weather_function_calling.py
   ```

3. Quan sát hai loại log:

   ```text
   [model yêu cầu] get_weather(...)
   [app thực thi]  -> ...
   ```

4. Xác nhận câu trả lời cuối được Gemini tổng hợp bằng tiếng Việt từ dữ liệu mock.

**Hoàn thành khi:** thấy model tạo lời gọi cho Hà Nội và Đà Nẵng, app chạy hàm, rồi model tạo câu trả lời cuối.

**Nếu lỗi:**

- `API key not valid`: key Gemini sai hoặc chưa được truyền vào đúng terminal.
- Không thấy function call: kiểm tra model và `TOOLS` trong file, đồng thời giữ prompt có yêu cầu thời tiết cụ thể.

---

### CP2 — Chạy MCP server/client cơ bản qua stdio

**Mục tiêu:** hiểu discovery và remote tool execution không cần LLM hay API key.

1. Từ root:

   ```powershell
   Set-Location ..\02-mcp-basics
   & ..\.venv\Scripts\python.exe .\weather_client.py
   ```

2. Client sẽ tự spawn `weather_server.py` bằng đúng interpreter đang chạy client.
3. Client gọi `list_tools()` và phải thấy `get_weather`.
4. Client gọi tool cho `Hanoi`, `Danang`, `Haiphong`.

**Hoàn thành khi:** terminal hiển thị tool do server công bố và ba kết quả mock. Không cần `GEMINI_API_KEY`.

**Điểm cần hiểu:** client có hard-code tên tool khi gọi thử, nhưng schema/description được khám phá từ server ở runtime; hàm thật chạy trong process server.

---

### CP3 — Kiểm tra ba vấn đề production

**Mục tiêu:** thực hành authentication, discovery và backward compatibility trước khi làm hệ thống thật.

#### CP3.1 Authentication

Mở hai PowerShell tại `03-production`.

Terminal 1:

```powershell
$env:MCP_AUTH_TOKEN = "dev-token-abc123"
& ..\.venv\Scripts\python.exe .\auth_server.py
```

Terminal 2:

```powershell
$env:MCP_AUTH_TOKEN = "dev-token-abc123"
& ..\.venv\Scripts\python.exe .\auth_client.py
```

Kết quả đúng: client liệt kê `get_weather` và nhận dữ liệu cho Hanoi. Sau đó có thể đổi token ở client để quan sát request bị từ chối.

> Token mặc định trong source chỉ dùng cho demo, tuyệt đối không dùng trong production.

#### CP3.2 Tool registry

Sau khi dừng auth server hoặc dùng terminal khác:

```powershell
& ..\.venv\Scripts\python.exe .\registry_client.py
```

Kết quả đúng:

- Registry tìm được `get_weather` và `get_weather_v2` theo tag `weather`.
- `best_match` chọn `get_weather_v2` vì version cao hơn và không deprecated.
- Client tự kết nối tới `versioned_server.py` rồi gọi tool.

#### CP3.3 Versioning

```powershell
& ..\.venv\Scripts\python.exe .\versioned_client.py
```

Kết quả đúng:

- Đọc được `server://info` với version `2.0.0`.
- Tool v1 vẫn chạy dù deprecated.
- Tool v2 trả JSON chi tiết và forecast.

**Hoàn thành CP3 khi:** cả ba demo chạy và có thể giải thích vì sao production cần auth, registry và versioning.

---

### CP4 — Cài và chạy Weather MCP server thật

**Mục tiêu:** chạy MCP server qua Streamable HTTP và kết nối được tới WeatherAPI.

1. Mở một PowerShell dành riêng cho server:

   ```powershell
   Set-Location "D:\LAB_VIN\Lab_day26\KX-DAY26-VuVanDien-2A202602418\04-lab\mcp-server"
   ```

2. Đồng bộ đúng lock file bằng Python 3.12:

   ```powershell
   uv sync --locked --python 3.12
   ```

3. Tạo `.env` từ template an toàn, rồi điền key:

   ```powershell
   Copy-Item .env.example .env
   ```

   ```dotenv
   WEATHERAPI_KEY=<WEATHERAPI_KEY_CUA_BAN>
   PORT=8085
   PYTHONUTF8=1
   ```

4. Chạy server và yêu cầu `uv` nạp file `.env`:

   ```powershell
   uv run --env-file .env python .\weather.py
   ```

5. Log mong đợi:

   ```text
   MCP server initialized with Streamable HTTP transport
   Available tools: get_current_weather, get_forecast, health_check
   Starting MCP server on http://0.0.0.0:8085/mcp
   ```

**Vì sao đặt `PORT` dù code có default:** code dùng thêm điều kiện `stdin.isatty()` để chọn transport. Đặt `PORT=8085` bảo đảm nhánh Streamable HTTP được chọn kể cả khi terminal/IDE không được nhận diện là TTY.

**Hoàn thành khi:** process tiếp tục chạy, không thoát, và log cho biết endpoint là `http://localhost:8085/mcp`.

**Lỗi thường gặp:**

- `Address already in use`: cổng 8085 đang bị process khác chiếm; dừng process đó hoặc đổi cả `PORT` và `MCP_SERVER_URL`.
- Server báo thiếu WeatherAPI key: điền key vào `.env`, chạy với `--env-file .env`, rồi restart server vì `API_KEY` được đọc lúc import.
- `uv sync --locked` báo lock không đồng bộ: không tự ý cập nhật lock trước khi kiểm tra thay đổi trong `pyproject.toml`.

---

### CP5 — Kiểm tra server và endpoint

**Mục tiêu:** phân biệt “process/cổng đang sống” với “tool MCP thực sự hoạt động”.

1. Giữ terminal CP4 đang chạy.
2. Trong terminal mới, thử reachability:

   ```powershell
   try {
       Invoke-WebRequest -Uri "http://localhost:8085/mcp" -Method Get
   } catch {
       $_.Exception.Response.StatusCode.value__
   }
   ```

3. HTTP 400, 405 hoặc 406 vẫn có thể có nghĩa endpoint MCP đang sống, vì một GET thường thiếu header/session đúng của giao thức MCP.
4. Không dùng kết quả này để tuyên bố tool đã chạy; phần đó được kiểm tra ở CP7 và CP8.

**Hoàn thành khi:** endpoint có phản hồi HTTP dưới 500 và log server cho thấy request tới `/mcp`.

**Ghi chú:** `health_check` là một **MCP tool**, không phải REST route `/health`. Load balancer hoặc Cloud Run health probe không thể mặc định gọi tool này như endpoint HTTP sức khỏe.

---

### CP6 — Cài và cấu hình Google ADK client

**Mục tiêu:** tạo đúng môi trường client và cấu hình hai đầu kết nối.

1. Mở PowerShell mới:

   ```powershell
   Set-Location "D:\LAB_VIN\Lab_day26\KX-DAY26-VuVanDien-2A202602418\04-lab\mcp-client"
   uv sync --locked --python 3.12
   ```

2. Tạo `04-lab/mcp-client/.env` từ template, rồi thay placeholder bằng key thật:

   ```powershell
   Copy-Item .env.example .env
   ```

   Nội dung cần có:

   ```dotenv
   GOOGLE_API_KEY=<GOOGLE_API_KEY_CUA_BAN>
   GEMINI_MODEL=gemini-3.5-flash-lite
   MCP_SERVER_URL=http://localhost:8085/mcp
   PYTHONUTF8=1
   ```

3. Không đặt `WEATHERAPI_KEY` trong file client. Key đó chỉ thuộc process server.
4. Kiểm tra `.env` không bị Git theo dõi:

   ```powershell
   git check-ignore -v .\.env
   ```

5. Giữ MCP server CP4 đang chạy.

**Hoàn thành khi:** `uv sync --locked` thành công, `.env` có hai biến client cần, và Git xác nhận file bị ignore.

**Lỗi thường gặp:**

- Dùng nhầm Gemini key làm WeatherAPI key hoặc ngược lại.
- Ghi URL thiếu `/mcp`.
- Đổi server port nhưng quên đổi `MCP_SERVER_URL`.
- Chạy ADK từ sai thư mục khiến không phát hiện package `weather_agent`.

---

### CP7 — Chạy kiểm tra tự động

**Mục tiêu:** phát hiện sớm lỗi môi trường, dependency, cấu trúc và endpoint.

Tại `04-lab/mcp-client`, trong khi server vẫn chạy:

```powershell
uv run python .\verify_setup.py
```

Năm nhóm nên pass:

```text
GOOGLE_API_KEY configured
Dependencies installed
weather_agent/agent.py và __init__.py tồn tại
MCP handshake succeeded; đủ ba tool; health_check thành công
Agent imported successfully
```

**Hoàn thành khi:** script kết thúc với `All checks passed!` và exit code 0.

**Nếu thất bại:** sửa từ lỗi đầu tiên xuống dưới, vì các lỗi sau có thể chỉ là hệ quả. Ví dụ dependency chưa cài sẽ làm cả dependency check và agent import cùng fail.

**Giới hạn của script:**

- Chỉ kiểm tra `GOOGLE_API_KEY`, không kiểm tra key còn quota hay được Gemini chấp nhận.
- Import thành công không bảo đảm WeatherAPI trả dữ liệu.
- Vì vậy CP8 là bắt buộc.

---

### CP8 — Test end-to-end bằng ADK Web

**Mục tiêu:** chứng minh toàn bộ chuỗi Browser → ADK → Gemini → MCP → WeatherAPI hoạt động.

1. Giữ server CP4 chạy.
2. Tại `04-lab/mcp-client`:

   ```powershell
   uv run adk web
   ```

3. Mở `http://localhost:8000`.
4. Chọn agent `weather_agent`.
5. Chạy lần lượt các test case:

| Test | Prompt gợi ý | Điều phải quan sát |
|---|---|---|
| Health | `Hãy kiểm tra weather server có đang hoạt động không.` | Agent gọi `health_check` |
| Current | `Thời tiết hiện tại ở Hà Nội như thế nào?` | Gọi `get_current_weather`; có nhiệt độ, độ ẩm, gió |
| Forecast | `Cho tôi dự báo thời tiết 3 ngày ở Đà Nẵng.` | Gọi `get_forecast` với `days=3`; có ba ngày |
| Multi-city | `So sánh thời tiết hiện tại ở Hanoi và Tokyo.` | Có thể gọi current tool nhiều lần và tổng hợp |
| Invalid city | `Thời tiết ở thành phố xyz-khong-ton-tai?` | Trả lỗi thân thiện, không bịa dữ liệu |

6. Đồng thời quan sát terminal server để chắc chắn có request/tool activity.
7. Nếu giao diện trả lời chung chung mà server không có request, agent có thể đang chạy fallback hoặc model không dùng tool.

**Definition of Done cho CP8:**

- ADK Web mở được và thấy `weather_agent`.
- Health tool chạy được.
- Ít nhất một current-weather request lấy dữ liệu thật.
- Forecast ba ngày chạy được.
- Server log có request tương ứng.
- Không có API key nào xuất hiện trong ảnh chụp/log nộp bài.

**Test bổ sung nên làm:** hỏi dự báo 7 ngày. Code hiện tại dùng `min(days, 3)`, vì vậy server chỉ yêu cầu tối đa 3 ngày từ WeatherAPI. Không test `days <= 0` như một case hợp lệ vì code chưa chặn cận dưới.

---

### CP9 — Build và chạy Docker local

**Mục tiêu:** xác nhận MCP server có thể chạy từ image giống hướng triển khai Cloud Run.

1. Bảo đảm Docker đang chạy.
2. Tại `04-lab/mcp-server`:

   ```powershell
   docker build -t weather-mcp:lab .
   ```

3. Chạy container, ánh xạ cổng host 8085 vào container 8080:

   ```powershell
   docker run --rm --name weather-mcp-lab `
     -p 8085:8080 `
     -e PORT=8080 `
     -e WEATHERAPI_KEY=$env:WEATHERAPI_KEY `
     weather-mcp:lab
   ```

4. Giữ client `.env` là `MCP_SERVER_URL=http://localhost:8085/mcp`.
5. Chạy lại CP7 và ít nhất hai test ở CP8.

**Hoàn thành khi:** container không crash, endpoint local vẫn là `http://localhost:8085/mcp`, và ADK gọi được tool.

**Lưu ý bảo mật:** truyền secret bằng `docker run -e` phù hợp cho lab local nhưng secret có thể xuất hiện qua lịch sử lệnh hoặc metadata container. Khi triển khai cloud, dùng secret manager và cấp quyền tối thiểu.

**Cloud Run:** Dockerfile đã chuẩn bị cho Cloud Run vì app lắng nghe `0.0.0.0` và tôn trọng `PORT`. Triển khai cloud cần thêm project/region, image registry, secret manager, IAM và quyết định endpoint công khai hay có auth. Đây là phần mở rộng, không nên coi `--allow-unauthenticated` là mặc định an toàn.

---

### CP10 — Hoàn thiện minh chứng và bàn giao

**Mục tiêu:** nộp một kết quả có thể kiểm tra lại, không kèm secret.

1. Lưu bằng chứng tối thiểu:

   - Output CP7 có `All checks passed!`.
   - Ảnh ADK Web cho current weather.
   - Ảnh ADK Web cho forecast ba ngày.
   - Log server cho thấy request tới MCP endpoint.
   - Nếu Docker là yêu cầu: output build và container chạy.

2. Kiểm tra secret và file rác:

   ```powershell
   Set-Location "D:\LAB_VIN\Lab_day26\KX-DAY26-VuVanDien-2A202602418"
   git status --short
   git diff --check
   git check-ignore -v .\04-lab\mcp-client\.env
   ```

3. Không nộp `.venv`, `.env`, key thật, cache Python hoặc `.adk` runtime data.
4. Ghi rõ cách tái chạy:

   ```text
   Terminal 1: mcp-server → điền .env → uv run --env-file .env python weather.py
   Terminal 2: mcp-client → cấu hình .env → uv run python verify_setup.py
   Terminal 2: uv run adk web → mở http://localhost:8000
   ```

**Hoàn thành khi:** người khác có thể clone repo, thêm hai key của họ và chạy lại theo ba dòng trên; Git không chuẩn bị commit bất kỳ secret nào.

## 7. Checklist nộp bài ngắn gọn

### Bắt buộc

- [ ] Python 3.12 và `uv` sẵn sàng.
- [ ] `mcp-server` và `mcp-client` đều `uv sync --locked` thành công.
- [ ] Server chạy Streamable HTTP tại `localhost:8085/mcp`.
- [ ] Client `.env` có `GOOGLE_API_KEY` và `MCP_SERVER_URL`.
- [ ] `verify_setup.py` pass.
- [ ] `health_check` chạy qua agent.
- [ ] Current weather trả dữ liệu thật.
- [ ] Forecast ba ngày trả dữ liệu thật.
- [ ] Có bằng chứng server nhận lời gọi MCP.
- [ ] Không commit `.env` hoặc API key.

### Nền tảng nên hoàn thành

- [ ] Giải thích được model không tự chạy function.
- [ ] Chạy được MCP `stdio` client/server.
- [ ] Giải thích được bearer auth.
- [ ] Giải thích được tool registry.
- [ ] Giải thích được backward compatibility giữa tool v1 và v2.

### Tùy chọn

- [ ] Docker image build thành công.
- [ ] Container vượt qua lại CP7/CP8.
- [ ] Triển khai Cloud Run với secret manager và chính sách IAM phù hợp.

## 8. Troubleshooting theo triệu chứng

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| `python` không được nhận diện | Python không ở `PATH` | Dùng `uv run ...` hoặc interpreter trong `.venv` |
| `uv sync` từ chối Python | Client cần Python 3.12 | `uv python install 3.12`, rồi thêm `--python 3.12` |
| Không kết nối được `:8085` | Server chưa chạy/sai transport/sai port | Đặt `PORT=8085`, restart, kiểm tra log |
| 404 | URL sai hoặc thiếu `/mcp` | Đặt `MCP_SERVER_URL=http://localhost:8085/mcp` |
| 400/405/406 khi GET `/mcp` | GET thường không phải MCP request hợp lệ | Dùng `verify_setup.py` và test ADK; đây vẫn có thể là dấu hiệu server sống |
| Weather tool báo thiếu key | `WEATHERAPI_KEY` không nằm trong process server | Đặt biến trong terminal server rồi restart |
| Agent import được nhưng không gọi tool | Toolset lazy-connect, server lỗi, agent fallback hoặc model không chọn tool | Xem cả log client và server; chạy prompt cụ thể ở CP8 |
| ADK không thấy `weather_agent` | Chạy `adk web` sai thư mục | Chạy từ `04-lab/mcp-client` |
| Gemini trả 401/403/quota | Google key sai, key bị hạn chế hoặc hết quota | Kiểm tra key/quota ở tài khoản Google |
| WeatherAPI trả lỗi | Key sai, city sai, quota hoặc network | Xem HTTP status/body ở terminal server |
| Port 8000/8085 bị chiếm | Process khác đang lắng nghe | Dừng process đó hoặc đổi đồng bộ port/URL |
| Forecast >3 ngày vẫn chỉ có 3 | Code giới hạn free tier bằng `min(days, 3)` | Đây là hành vi hiện tại, không phải lỗi |

## 9. Các giới hạn hiện tại và hướng cải tiến

Để không nhầm demo với production, cần biết các giới hạn sau:

1. Lab 04 chưa có authentication cho MCP endpoint.
2. `WEATHERAPI_KEY` được đọc khi import; đổi biến trong lúc server chạy không có tác dụng cho tới khi restart.
3. `get_forecast` giới hạn `days` trong khoảng 1–3 ngày để phù hợp free tier.
4. Tool trả chuỗi trình bày thay vì structured JSON, nên client khó tái sử dụng dữ liệu theo kiểu máy đọc.
5. Xử lý lỗi trả thông báo chung và dùng `print`; production nên có structured logging, error codes và tracing.
6. `health_check` không kiểm tra WeatherAPI hoặc Gemini, và không phải HTTP health route.
7. Agent fallback không có tool có thể khiến giao diện vẫn mở nhưng không thực hiện nhiệm vụ thời tiết thật.
8. Chưa có automated test mock WeatherAPI, integration test MCP hoặc CI pipeline.
9. Dockerfile chưa chạy bằng non-root user và chưa có container health check.
10. Cloud deployment cần auth, secret manager, rate limiting, timeout/retry và observability.

Thứ tự cải tiến hợp lý sau khi lab cơ bản pass:

```text
Validate input
  → structured tool output
  → unit test với mock HTTP
  → MCP integration test
  → auth + secret manager
  → logging/tracing
  → Docker hardening
  → Cloud Run deployment
```

## 10. Câu hỏi tự kiểm tra

Nếu trả lời được các câu sau, bạn đã nắm đúng mục tiêu bài lab:

1. Trong phần 01, ai thực thi `get_weather`: Gemini hay app Python?
2. MCP client biết schema của tool bằng cách nào?
3. Vì sao phần 02 không cần Gemini API key?
4. ADK đã thay thế đoạn logic thủ công nào của phần 01?
5. Vì sao server và client Lab 04 cần hai API key khác nhau?
6. Vì sao HTTP 405 khi GET `/mcp` chưa chắc có nghĩa server hỏng?
7. Vì sao `verify_setup.py` pass vẫn chưa đủ để kết luận bài lab hoàn thành?
8. Vì sao cần giữ tool v1 khi phát hành tool v2?
9. Vì sao không nên dùng token tĩnh trong `03-production/auth_server.py` cho production?
10. Nếu deploy MCP server lên Cloud Run, biến nào của client phải thay đổi?

## 11. Tóm tắt đường chạy nhanh nhất

Nếu đã hiểu phần nền tảng và chỉ cần hoàn thành Lab 04:

**Terminal 1 — server:**

```powershell
Set-Location .\04-lab\mcp-server
uv sync --locked --python 3.12
# Điền WEATHERAPI_KEY và PORT=8085 trong file .env
uv run --env-file .env python .\weather.py
```

**Terminal 2 — client:**

```powershell
Set-Location .\04-lab\mcp-client
uv sync --locked --python 3.12
# Tạo .env chứa GOOGLE_API_KEY và MCP_SERVER_URL=http://localhost:8085/mcp
uv run python .\verify_setup.py
uv run adk web
```

Sau đó mở `http://localhost:8000`, chọn `weather_agent`, chạy bộ test ở CP8 và hoàn tất checklist CP10.
