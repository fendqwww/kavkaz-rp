// KAVKAZ RP — лаунчер v0.1.
// Берёт адрес сервера из config.json в репозитории, показывает, работает ли сервер,
// проверяет, установлен ли FiveM, и по кнопке «Играть» открывает fivem://connect/<адрес>.
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
    let base = std::env::var_os("APPDATA")?;
    Some(PathBuf::from(base).join("KavkazRP").join("address.txt"))
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
fn fivem_installed() -> bool {
    std::env::var_os("LOCALAPPDATA")
        .map(|d| PathBuf::from(d).join("FiveM").join("FiveM.exe").exists())
        .unwrap_or(false)
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

#[tauri::command]
fn play(address: String) -> Result<(), String> {
    let a = with_port(&address);
    if !valid_address(&a) {
        return Err("адрес сервера ещё не задан".into());
    }
    open_external(&format!("fivem://connect/{a}"))
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
            fivem_installed,
            set_address,
            play,
            open_link
        ])
        .run(tauri::generate_context!())
        .expect("ошибка запуска лаунчера");
}
