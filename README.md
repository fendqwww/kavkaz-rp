# KAVKAZ RP

RP-сервер FiveM на Qbox. Правила проекта — в [CLAUDE.md](CLAUDE.md).

## установка на windows

1. скачай [`setup/install.ps1`](setup/install.ps1) (кнопка «Download raw file»).
2. открой PowerShell и выполни:
   ```
   powershell -ExecutionPolicy Bypass -File $HOME\Downloads\install.ps1
   ```
3. скрипт сам: поставит Git, Node.js, Python, MariaDB, 7-Zip; создаст `C:\kavkaz`; скачает recommended-билд FXServer; придумает пароли и положит их в `C:\kavkaz\secrets.cfg`; настроит MariaDB; клонирует репозиторий в `C:\project\kavkaz`; сделает ярлыки «Запустить сервер» и «Остановить сервер»; запустит txAdmin.
4. в конце он напечатает 3 ручных шага (ключ Cfx.re, рецепт Qbox в txAdmin, вход в игру).
