// KAVKAZ RP — лаунчер v0.2.
// Берёт адрес сервера из config.json в репозитории, показывает, работает ли сервер,
// проверяет FiveM и GTA, по кнопке «Играть» открывает fivem://connect/<адрес>.
// Настройки: свой адрес сервера, закрытие лаунчера после запуска, очистка кэша FiveM, папка FiveM.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::time::Duration;

const CONFIG_URL: &str =
    "https://raw.githubusercontent.com/fendqwww/kavkaz-rp/claude/serene-franklin-9x1dw5/launcher/config.json";
const DEFAULT_PORT: u16 = 30120;

#[derive(Serialize, Deserialize, Clone, Default)]
struct News {
    #[serde(default)]
    date: String,
    #[serde(default)]
    title: String,
    #[serde(default)]
    text: String,
}

#[derive(Serialize, Deserialize, Clone, Default)]
struct Config {
    #[serde(default)]
    server_name: String,
    #[serde(default)]
    address: String,
    #[serde(default)]
    telegram: String,
    #[serde(default)]
    site: String,
    #[serde(default)]
    news: Vec<News>,
    /// адрес задан вручную в настройках лаунчера
    #[serde(default)]
    address_is_custom: bool,
}

/// настройки лаунчера, лежат в %APPDATA%\KavkazRP\settings.json
#[derive(Serialize, Deserialize, Clone, Default)]
struct Settings {
    /// закрыть лаунчер после запуска игры
    #[serde(default)]
    close_on_play: bool,
}

/// результат проверки установки
#[derive(Serialize)]
struct GameState {
    fivem: bool,
    /// "ok" — GTA найдена, "missing" — путь в FiveM есть, а игры там нет, "unknown" — FiveM ещё не запускался
    gta: &'static str,
}

#[derive(Serialize)]
struct CacheResult {
    freed_mb: u64,
    removed: u32,
}

/// только «работает / не работает» — онлайн и слоты специально не показываем
#[derive(Serialize)]
struct Status {
    online: bool,
}

fn http() -> reqwest::Client {
    reqwest::Client::builder()
        .timeout(Duration::from_secs(5))
        .build()
        .expect("http client")
}

fn settings_file() -> Option<PathBuf> {
    Some(PathBuf::from(std::env::var_os("APPDATA")?).join("KavkazRP").join("address.txt"))
}

fn app_dir() -> Option<PathBuf> {
    Some(PathBuf::from(std::env::var_os("APPDATA")?).join("KavkazRP"))
}

fn fivem_dir() -> Option<PathBuf> {
    Some(PathBuf::from(std::env::var_os("LOCALAPPDATA")?).join("FiveM"))
}

fn read_settings() -> Settings {
    app_dir()
        .and_then(|d| std::fs::read_to_string(d.join("settings.json")).ok())
        .and_then(|t| serde_json::from_str(&t).ok())
        .unwrap_or_default()
}

fn dir_size(path: &std::path::Path) -> u64 {
    let Ok(rd) = std::fs::read_dir(path) else { return 0 };
    rd.flatten()
        .map(|e| match e.metadata() {
            Ok(m) if m.is_dir() => dir_size(&e.path()),
            Ok(m) => m.len(),
            Err(_) => 0,
        })
        .sum()
}

/// запущен ли сейчас FiveM (кэш при запущенной игре трогать нельзя)
fn fivem_running() -> bool {
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        const CREATE_NO_WINDOW: u32 = 0x0800_0000;
        std::process::Command::new("tasklist")
            .creation_flags(CREATE_NO_WINDOW)
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).to_lowercase().contains("fivem"))
            .unwrap_or(false)
    }
    #[cfg(not(windows))]
    {
        false
    }
}

fn custom_address() -> Option<String> {
    let text = std::fs::read_to_string(settings_file()?).ok()?;
    let a = text.trim().to_string();
    if a.is_empty() { None } else { Some(a) }
}

/// "1.2.3.4" -> "1.2.3.4:30120"; домен или адрес с портом оставляем как есть
fn with_port(address: &str) -> String {
    let a = address.trim().trim_start_matches("http://").trim_start_matches("https://").trim_end_matches('/');
    if a.contains(':') { a.to_string() } else { format!("{a}:{DEFAULT_PORT}") }
}

/// разрешаем только символы адреса: буквы, цифры, точки, дефисы и двоеточие
fn valid_address(a: &str) -> bool {
    !a.is_empty() && a.len() <= 253 && a.chars().all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '-' || c == ':')
}

#[tauri::command]
async fn get_config() -> Config {
    let mut cfg = match http().get(CONFIG_URL).send().await {
        Ok(r) if r.status().is_success() => r.json::<Config>().await.unwrap_or_default(),
        _ => Config::default(),
    };
    if let Some(a) = custom_address() {
        cfg.address = a;
        cfg.address_is_custom = true;
    }
    if cfg.server_name.is_empty() {
        cfg.server_name = "KAVKAZ RP".into();
    }
    cfg
}

#[tauri::command]
async fn get_status(address: String) -> Status {
    let offline = Status { online: false };
    if !valid_address(&with_port(&address)) {
        return offline;
    }
    let url = format!("http://{}/dynamic.json", with_port(&address));
    let Ok(resp) = http().get(url).send().await else { return offline };
    if !resp.status().is_success() {
        return offline;
    }
    Status { online: true }
}

#[tauri::command]
fn game_state() -> GameState {
    let Some(dir) = fivem_dir() else { return GameState { fivem: false, gta: "unknown" } };
    let fivem = dir.join("FiveM.exe").exists();
    // FiveM записывает путь к GTA V в CitizenFX.ini (строка IVPath=...)
    let gta = match std::fs::read_to_string(dir.join("CitizenFX.ini")) {
        Ok(ini) => match ini.lines().find_map(|l| l.trim().strip_prefix("IVPath=")) {
            Some(p) if PathBuf::from(p.trim()).join("GTA5.exe").exists() => "ok",
            Some(_) => "missing",
            None => "unknown",
        },
        Err(_) => "unknown",
    };
    GameState { fivem, gta }
}

#[tauri::command]
fn get_settings() -> Settings {
    read_settings()
}

#[tauri::command]
fn set_settings(settings: Settings) -> Result<(), String> {
    let dir = app_dir().ok_or("не найдена папка APPDATA")?;
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let text = serde_json::to_string_pretty(&settings).map_err(|e| e.to_string())?;
    std::fs::write(dir.join("settings.json"), text).map_err(|e| e.to_string())
}

/// чистит кэш FiveM: помогает, если игра зависает на загрузке или ругается на файлы сервера.
/// сама GTA и настройки FiveM не затрагиваются, при следующем входе ресурсы сервера скачаются заново
#[tauri::command]
fn clear_fivem_cache() -> Result<CacheResult, String> {
    let dir = fivem_dir().ok_or("не найдена папка LOCALAPPDATA")?;
    let data = dir.join("FiveM.app").join("data");
    if !data.exists() {
        return Err("кэш FiveM не найден: FiveM ещё не запускался".into());
    }
    if fivem_running() {
        return Err("FiveM сейчас запущен. Закрой игру и FiveM, потом повтори".into());
    }
    let (mut bytes, mut removed) = (0u64, 0u32);
    for name in ["cache", "server-cache", "server-cache-priv"] {
        let p = data.join(name);
        if p.is_dir() {
            bytes += dir_size(&p);
            std::fs::remove_dir_all(&p).map_err(|e| format!("не удалось очистить {name}: {e}"))?;
            removed += 1;
        }
    }
    Ok(CacheResult { freed_mb: bytes / 1024 / 1024, removed })
}

#[tauri::command]
fn open_fivem_folder() -> Result<(), String> {
    let dir = fivem_dir().filter(|d| d.exists()).ok_or("папка FiveM не найдена")?;
    #[cfg(windows)]
    {
        std::process::Command::new("explorer").arg(&dir).spawn().map(|_| ()).map_err(|e| e.to_string())
    }
    #[cfg(not(windows))]
    {
        std::process::Command::new("xdg-open").arg(&dir).spawn().map(|_| ()).map_err(|e| e.to_string())
    }
}

#[tauri::command]
fn set_address(address: String) -> Result<(), String> {
    let path = settings_file().ok_or("не найдена папка APPDATA")?;
    let a = address.trim();
    if a.is_empty() {
        let _ = std::fs::remove_file(&path);
        return Ok(());
    }
    if !valid_address(&with_port(a)) {
        return Err("адрес может содержать только буквы, цифры, точки, дефисы и двоеточие".into());
    }
    std::fs::create_dir_all(path.parent().unwrap()).map_err(|e| e.to_string())?;
    std::fs::write(&path, a).map_err(|e| e.to_string())
}

fn open_external(url: &str) -> Result<(), String> {
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        const CREATE_NO_WINDOW: u32 = 0x0800_0000;
        std::process::Command::new("cmd")
            .args(["/C", "start", "", url])
            .creation_flags(CREATE_NO_WINDOW)
            .spawn()
            .map(|_| ())
            .map_err(|e| e.to_string())
    }
    #[cfg(not(windows))]
    {
        std::process::Command::new("xdg-open").arg(url).spawn().map(|_| ()).map_err(|e| e.to_string())
    }
}

/// FiveM со ссылкой fivem:// запускается только из проводника или браузера:
/// через `cmd /C start` он пишет «should be launched directly from the shell». поэтому отдаём ссылку explorer.exe.
fn open_fivem(url: &str) -> Result<(), String> {
    #[cfg(windows)]
    {
        std::process::Command::new("explorer").arg(url).spawn().map(|_| ()).map_err(|e| e.to_string())
    }
    #[cfg(not(windows))]
    {
        open_external(url)
    }
}

#[tauri::command]
fn play(app: tauri::AppHandle, address: String) -> Result<(), String> {
    let a = with_port(&address);
    if !valid_address(&a) {
        return Err("адрес сервера ещё не задан".into());
    }
    open_fivem(&format!("fivem://connect/{a}"))?;
    if read_settings().close_on_play {
        std::thread::spawn(move || {
            std::thread::sleep(Duration::from_secs(4));
            app.exit(0);
        });
    }
    Ok(())
}

#[tauri::command]
fn open_link(url: String) -> Result<(), String> {
    if !(url.starts_with("https://") || url.starts_with("http://")) || url.contains(['"', '&', '|', '^', '<', '>']) {
        return Err("недопустимая ссылка".into());
    }
    open_external(&url)
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            get_config,
            get_status,
            game_state,
            get_settings,
            set_settings,
            clear_fivem_cache,
            open_fivem_folder,
            set_address,
            play,
            open_link
        ])
        .run(tauri::generate_context!())
        .expect("ошибка запуска лаунчера");
}
