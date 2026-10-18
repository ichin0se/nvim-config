# Windows LazyVim 開発環境・操作一覧

Neovim 内では `:DevGuide` または `Space h D` でこの一覧を開けます。`Space f f` は Space → f → f と順に押す意味です。以下は原則ノーマルモードの操作です。挿入モードからは `Esc` で戻ります。

## 別の PC で再現する

対象は Windows 11 x64、Windows PowerShell 5.1 または PowerShell 7 です。まず Windows Terminal と App Installer（WinGet）、Git、GitHub CLI を用意してください。Git / GitHub CLI は `winget install --id Git.Git -e` / `winget install --id GitHub.cli -e` で導入できます。その後ターミナルを開き直し、非公開リポジトリにアクセスできる GitHub アカウントで実行します。

```powershell
gh auth login
gh auth setup-git
$config = Join-Path $env:LOCALAPPDATA 'nvim'
if (Test-Path -LiteralPath $config) { throw '既存の nvim 設定をバックアップして別名にしてから再実行してください' }
gh repo clone ichin0se/nvim-config $config
powershell -NoProfile -ExecutionPolicy Bypass -File "$config/scripts/bootstrap.ps1" -InstallBuildTools -InstallFont
powershell -NoProfile -ExecutionPolicy Bypass -File "$config/scripts/configure-terminal.ps1"
codex login
nvim
```

Neovim 内で `:LazyHealth` を実行して確認します。新たな PATH とフォントを反映するため、導入完了後に Windows Terminal と Neovim を再起動してください。Terminal の設定ファイルがまだない場合は Terminal を一度起動してから設定スクリプトを実行します。

`bootstrap.ps1` は不足する CLI、Python provider 用の専用仮想環境、プラグイン、Mason の LSP / formatter / debugger、Treesitter パーサー、Markdown preview を導入します。既存の設定ディレクトリへファイルをコピーしません。このリポジトリは `%LOCALAPPDATA%/nvim` にクローンしてください。

- `-InstallBuildTools` は Rust MSVC ビルド用の Visual Studio C++ Build Tools / Windows SDK がない場合に導入します。管理者承認が必要になる場合があります。既存環境があれば再利用します。
- `-InstallFont` は HackGen Console NF を現在のユーザー用に導入します。
- `-WhatIf` で変更予定だけを表示できます。例: `powershell -NoProfile -ExecutionPolicy Bypass -File "$config/scripts/bootstrap.ps1" -InstallBuildTools -InstallFont -WhatIf`。
- `-SkipTools` / `-SkipRust` / `-SkipCodex` / `-SkipProvider` / `-SkipNeovimBootstrap` で対応する工程を省略できます。
- Terminal 設定も `configure-terminal.ps1 -WhatIf` で確認できます。自動検出した Terminal 設定の `profiles.defaults` だけを変更し、既存プロファイルや個別設定を保持します。個別プロファイルに透明度等の上書きがある場合はそちらが優先されます。
- Terminal 設定は変更前にバックアップします。JSONC のコメントや末尾カンマは保存時に通常の JSON に整形されます。特殊な配置は `configure-terminal.ps1 -SettingsPath '設定ファイルのフルパス'` で指定できます。

Python provider は `%LOCALAPPDATA%/nvim-data/python-provider` に作成します。独自の Python を使いたい場合は `NVIM_PYTHON3_HOST_PROG` に `pynvim` をインストール済みの Python 実行ファイルを指定できます。ユーザー名や Python のインストール先は設定に固定していません。

`lazy-lock.json` でプラグインのコミットを固定し、初回導入後も元のロックファイルへ復元します。WinGet / Mason / npm / Rust の外部ツールは各配布元の利用可能な版を導入するため、OS や全バイナリの完全一致ではなく、同じ機能構成の再構築を目的としています。作成元で確認した主な版は Neovim 0.12.6、Python 3.14.7、Node 24.20.0、Rust 1.99.1、GitUI 0.28.1、Codex CLI 0.163.0 です。

認証情報、Git のユーザー設定、編集中ファイル、セッション、Undo 履歴、バックアップ本文、ダウンロード済みのツール本体はリポジトリに含めません。Git のコミット名・メールは「GitHub・Codex」の手順で各 PC に設定してください。

## 最初に

Windows Terminal と Neovim を再起動して、新しい PATH を反映してください。プロジェクトのディレクトリで起動すると、LSP・検索・Git・Codex・セッションの基準もそのプロジェクトになります。

```powershell
cd C:/path/to/project
nvim
nvim file1.py file2.py
nvim -O file1.cpp file2.cpp
```

`-O` は左右分割、`-o` は上下分割です。ファイル引数なしで起動すると、そのディレクトリと Git ブランチの前回のファイル一覧・分割配置を自動復元します。

## 導入・設定済み機能

| 機能 | プラグイン・設定 | 使い方・動作 |
| --- | --- | --- |
| 背景の透明度 60% | Windows Terminal + Tokyonight | Terminal の不透明度 `40`、通常背景・サイドバーを透過。ポップアップは読みやすい背景を維持 |
| 日本語・アイコン | HackGen Console NF | 既存の日本語対応 Nerd Font を Terminal に設定 |
| 行番号の強調 | Neovim + Tokyonight | 現在行は絶対番号をシアン太字で表示。他の行は相対番号 |
| スペース・タブ可視化 | listchars | スペース `·`、タブ `»`、改行しないスペース `␣`。`Space u W` で切替 |
| インデントガイド | Snacks indent | インデントと現在のスコープを表示 |
| ステータスバー | lualine | モード・ブランチ・差分・診断・パス・位置。幅に応じ LSP 名・文字コード・改行形式も表示 |
| バッファタブ | bufferline | 開いているファイルを上部に常時表示 |
| セッション永続化 | persistence.nvim | 終了時保存、同じディレクトリ・Git ブランチで自動復元 |
| 永続 Undo | undofile | 再起動後も `u` で戻す、`Ctrl+r` でやり直す |
| バックアップ・復旧 | backup / swap | 保存前の内容をバックアップ。不意の終了時は `:recover` |
| スクラッチメモ | Snacks scratch | `Space .` で開閉、`Space S` で過去のメモを選択 |
| 外部変更の再読込 | autoread + checktime | フォーカス復帰・ファイル移動・操作待ち・ターミナル終了後に確認。未保存の編集があるファイルは上書きしない |
| ファイルツリー | Snacks explorer | `Space e`。ドットファイル表示、Git の無視対象は通常隠す |
| ファイル検索 | Snacks picker + fd | `Space f f` |
| 全文検索 | Snacks picker + ripgrep | `Space /` |
| ポップアップ補完 | blink.cmp | LSP・パス・スニペット・バッファ内単語を自動補完。説明と関数の引数も表示 |
| 保存時の自動整形 | conform.nvim + LazyVim | `:w` で実行。手動は `Space c f` または `:Format` |
| 構文強調 | nvim-treesitter | Python / Rust / C++ / CMake / JSON / YAML / Markdown など |
| スコープ固定表示 | treesitter-context | 関数・クラスなどを画面上部に最大 3 行表示 |
| 診断一覧 | trouble.nvim | `Space x x` |
| 高速ジャンプ | flash.nvim | `s` → 検索文字 → 表示されたラベル |
| 括弧の自動補完 | mini.pairs | 開き括弧・引用符の対応する閉じ文字を自動挿入 |
| 囲み文字の編集 | mini.surround | `gsa` 追加、`gsd` 削除、`gsr` 置換。例: `gsaiw)` で単語を括弧で囲む |
| コメント切替 | Neovim + ts-comments | `gcc` 現在行、選択して `gc` 選択範囲 |
| 一括置換 | grug-far | `Space s r` |
| TODO 一覧 | todo-comments | `Space s t` |
| Git 差分の行表示 | gitsigns.nvim | 左端に変更行表示。`]h` / `[h` で差分へ移動 |
| GitUI | GitUI + Snacks terminal | `Space g U`。アプリ内の `h` でヘルプ |
| LazyGit | lazygit + Snacks | 従来の `Space g g` も利用可能 |
| 差分・履歴 | diffview.nvim | `Space g D` 差分、`Space g H` ファイル履歴、`Space g C` 閉じる |
| GitHub Issue / PR | octo.nvim + gh | `Space g O` または `:Octo` |
| GitHub を開く | Snacks gitbrowse | `Space g B` でブラウザ表示 |
| Codex | 公式 Codex CLI + Snacks terminal | `Space a a` 起動・再表示、`Space a r` 会話再開、`Space a f` 現在ファイルの絶対パスをコピー |
| デバッグ | nvim-dap + dap-ui | Python は debugpy、Rust / C++ は codelldb |
| テスト実行 | neotest | Python / Rust のテストをエディタ内から実行 |
| ビルド・タスク管理 | overseer.nvim | `Space o o` 実行、`Space o w` 一覧、`Space o t` タスク操作 |
| Markdown 表示 | render-markdown.nvim | 見出し・表・コードブロックを編集画面内で整形表示 |
| Markdown プレビュー | markdown-preview.nvim | Markdown で `Space c p` または `:MarkdownPreviewToggle` |
| JSON / YAML スキーマ | SchemaStore + 各 LSP | キー補完・型チェック |
| キー操作の案内 | which-key.nvim | `Space` を押して少し待つ |
| プラグイン管理 | lazy.nvim | `Space l` または `:Lazy` |
| LSP・ツール管理 | mason.nvim | `:Mason` |
| 追加機能の管理 | LazyVim Extras | `:LazyExtras` |

## ファイル・バッファ・画面分割

| 操作 | キー・コマンド |
| --- | --- |
| 保存 / 終了 / 保存して終了 | `:w` / `:q` / `:wq` |
| バッファ一覧 | `Space ,` または `:ls` |
| 前 / 次のバッファ | `[b` / `]b` |
| バッファを閉じる | `Space b d` |
| 左右 / 上下分割 | `Space w v` / `Space w s`、または `Space \|` / `Space -` |
| 分割間の移動 | `Ctrl+h/j/k/l` |
| 分割サイズを均等に / 閉じる | `Space w e` / `Space w c` |
| ビルド・実行用ターミナルを下側に開く | `Space w t` または `:BuildTerminal` |
| ターミナル表示・非表示 | `Ctrl+/` |
| ターミナル入力からノーマルモードへ | `Ctrl+\` → `Ctrl+n` |

バッファは開いているファイル、ウィンドウはその表示領域です。同じファイルを複数表示することもできます。`Space b d` はディスク上のファイルを削除しません。

### 分割ターミナルでビルド・実行

`Space w t` で、プロジェクトのルートを作業ディレクトリとするシェルを下側に開きます。コードを上に表示したまま、`uv run python main.py`、`cargo run`、`cargo test`、`cmake --build build` などを実行できます。

- ターミナルから上の編集画面へ: `Ctrl+k`
- 編集画面から下のターミナルへ: `Ctrl+j`。または `Space w t`
- ターミナルを隠す: `Ctrl+\` → `Ctrl+n` → `q`
- 再表示: `Space w t`。同じプロジェクトのシェルと出力履歴を再利用します
- 出力をスクロール: `Ctrl+\` → `Ctrl+n` のあと通常の `k` / `Ctrl+u` 等。入力へ戻るには `i`
- シェル自体を終了: `exit`

表示・非表示だけでは実行中のビルドやシェルを終了しません。Neovim を終了したときはターミナルのプロセスも終了し、次回は新しいシェルになります。

## 補完・LSP・整形

| 操作 | キー・コマンド |
| --- | --- |
| 補完の次 / 前の候補 | 挿入モードで `Ctrl+n` / `Ctrl+p` |
| 選択した候補を確定 / 先頭候補を確定 | `Enter` / `Ctrl+y` |
| 補完を手動表示 / 閉じる | `Ctrl+Space` / `Ctrl+e` |
| スニペットの次の入力欄 | `Tab` |
| 定義 / 宣言 / 参照 | `gd` / `gD` / `gr` |
| 実装 / 型定義 | `gI` / `gy` |
| ドキュメント / 引数ヘルプ | `K` / `gK` |
| 名前変更 / コードアクション | `Space c r` / `Space c a` |
| 次 / 前の診断 | `]d` / `[d` |
| LSP 状態 / formatter 状態 | `:checkhealth vim.lsp` / `:ConformInfo` |
| 保存時整形を全体 / 現在バッファで切替 | `Space u f` / `Space u F` |

候補の自動選択は無効です。候補を選択せず `Enter` を押すと改行します。自動保存は行わず、保存操作のときに整形します。

| 言語 | LSP・診断 | 保存時 formatter |
| --- | --- | --- |
| Python | basedpyright + Ruff | Ruff import 整列 → Ruff format |
| Rust | rust-analyzer + Clippy | rustfmt |
| C / C++ | clangd | clang-format |
| CMake | neocmakelsp + cmakelint | cmake-format |
| Lua | lua-language-server | StyLua |
| JSON / YAML / Markdown | 各言語の LSP・ツール | Prettier（プロジェクト内の版を優先） |

`pyproject.toml`、`ruff.toml`、`rustfmt.toml`、`.clang-format`、`.editorconfig` などのプロジェクト設定を使えます。

## Python

Python 本体に加え `uv` を導入しています。プロジェクトごとに `.venv` を使ってください。

```powershell
uv init
uv add --dev pytest
uv sync
nvim
```

既存プロジェクトでは必要なコマンドだけ実行します。`Space c v` で仮想環境を選択できます。Python のインデントはスペース 4 個です。Neovim 自身の Python provider とプロジェクトの仮想環境は別です。

## Rust

Rust stable / Cargo / rust-analyzer / rustfmt / Clippy / rust-src を用意しています。

```powershell
cargo new sample
cd sample
cargo run
cargo test
cargo clippy
cargo fmt
```

`:RustLsp runnables` は実行対象、`:RustLsp testables` はテスト、`:RustLsp debuggables` はデバッグ対象の選択です。`Cargo.toml` では crates.nvim による依存クレートの情報・操作を利用できます。

## C / C++ と CMake

clangd / clang-format / codelldb、WinLibs GCC / G++、CMake、Ninja を利用できます。Visual Studio のツールも既存環境にあります。clangd にコンパイル条件を伝えるため `compile_commands.json` を用意してください。

```powershell
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build
Copy-Item build/compile_commands.json ./compile_commands.json
ctest --test-dir build --output-on-failure
```

CMake Presets があるプロジェクトではそのプリセットを使ってください。`CMakeLists.txt` のあるディレクトリで起動すると cmake-tools が読み込まれ、`:CMakeGenerate` / `:CMakeBuild` / `:CMakeRun` / `:CMakeDebug` を利用できます。cmake-tools は生成したコンパイルデータベースをコピーする設定です。C++ のテストは CTest 等を Overseer またはターミナルから実行します。

## テスト・デバッグ

| 操作 | キー |
| --- | --- |
| 近くのテスト / ファイルのテスト | `Space t r` / `Space t t` |
| 全テスト / 前回のテスト | `Space t T` / `Space t l` |
| 結果一覧 / 出力 | `Space t s` / `Space t o` |
| 近くのテストをデバッグ | `Space t d` |
| ブレークポイント / 条件付きブレークポイント | `Space d b` / `Space d B` |
| 開始・続行 | `Space d c` |
| ステップオーバー / イン / アウト | `Space d O` / `Space d i` / `Space d o` |
| デバッグ UI / 終了 | `Space d u` / `Space d t` |

Python のテストには対象環境の `pytest` が必要です。C++ は Debug ビルドした実行ファイルを指定します。`.vscode/launch.json` の DAP 設定も利用できます。

## GitHub・Codex

GitHub CLI と Codex CLI の認証情報はこのリポジトリに含めません。別の PC ではターミナルで `gh auth login` / `codex login` を実行してください。

Git のコミット情報も各 PC で `git config --global user.name "表示名"` / `git config --global user.email "メールアドレス"` を設定してください。個人のメールを公開したくない場合は、GitHub のメール設定に表示される自分の noreply アドレスを使います。

Octo は `:Octo issue list` / `:Octo pr list` 等を利用できます。Issue・PR の編集バッファで `:w` を実行すると GitHub へ保存します。

Codex はプロジェクト内で起動する対話型の公式 CLI として連携しています。`Space a f` はパスのコピーだけです。必要なファイルや指示は Codex の入力欄で指定してください。起動だけで依頼を自動送信する設定にはしていません。

Codex / GitUI を隠すには、ターミナル入力モードで `Ctrl+/`、または `Ctrl+\` → `Ctrl+n` → `q` を使います。再表示は `Space a a` / `Space g U` です。ノーマルモードの `Ctrl+/` は通常のシェル用ターミナルを開きます。

## セッション・履歴・復旧

| 操作 | キー |
| --- | --- |
| セッションの手動保存 | `Space q W` |
| 現在ディレクトリのセッション復元 | `Space q s` |
| セッション選択 / 最後のセッション復元 | `Space q S` / `Space q l` |
| 今回のセッション保存を停止 | `Space q d` |

セッションはファイル一覧・タブ・分割配置を保存します。未保存の本文や実行中ターミナルのプロセスはセッションだけでは復元しません。本文は `:w` で保存します。保存前の内容はバックアップ、異常終了時の編集は swap、保存後の履歴は永続 Undo で保護します。

外部更新は未変更のバッファだけ自動再読込します。未保存の編集があるときは保持します。ディスク側を採用すると決めた場合だけ `:edit!` を使ってください。

## 設定場所・メンテナンス

設定は `%LOCALAPPDATA%/nvim`、プラグイン・LSP・履歴は `%LOCALAPPDATA%/nvim-data` です。

| ファイル | 内容 |
| --- | --- |
| `lua/config/options.lua` | 行番号、空白、Undo、バックアップ、UTF-8、Python provider |
| `lua/config/autocmds.lua` | 外部更新の再読込、Python インデント |
| `lua/config/keymaps.lua` | 分割、セッション保存、操作一覧、整形コマンド |
| `lua/config/devtools.lua` | GitUI / Codex / Diffview 起動 |
| `lua/plugins/appearance.lua` | 透過テーマ、行番号、ステータスバー |
| `lua/plugins/editor.lua` | 自動セッション復元・補完 |
| `lua/plugins/languages.lua` | LSP・formatter・debugger・CMake |
| `lua/plugins/workflow.lua` | Git / GitHub / Codex |
| `lua/plugins/snacks.lua` | ツリー・インデント・画像機能の扱い |
| `lazyvim.json` | 有効な Extras |

透明度は `%LOCALAPPDATA%/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json` の `profiles.defaults.opacity` です。`40` が不透明度 40%、透明度 60% です。`useAcrylic=false` なのでぼかしはありません。

既存の Neovim 設定がある PC では、クローンする前にその設定をバックアップしてください。Terminal 設定の適用スクリプトは、変更前の設定を同じディレクトリにバックアップします。Undo・swap・バックアップ本文・セッション・認証情報は Git 管理しません。

`:Lazy health` は lazy.nvim の診断、`:LazyHealth` は全プラグインをロードして全体診断です。任意の言語ランタイム・provider の WARNING は残る場合があります。LuaRocks は依存プラグインがないため無効です。

Snacks の画像表示・プレビューは Windows Terminal 用に無効化しています。現行 Snacks は無効な画像機能の依存も ERROR として検査するため、画像機能だけ `meta.health` で診断対象外にしています。画像変換・PDF・LaTeX・Mermaid 用ツールは導入していません。内部仕様のフラグなので更新後は再確認してください。対応端末・ツールを用意して `image.enabled=true` にすると画像診断も復帰します。

## 検証済み

導入スクリプトは Windows PowerShell 5.1 で構文、`-WhatIf` の無変更、設定ファイルの一時 fixture を検証しています。別の PC へのフルインストールと PowerShell 7 での実行は未検証です。

最終の `:LazyHealth` は ERROR 0 を確認しています。任意ツールや既定のキーマップ重複に関する WARNING は残ります。

通常起動の UI を接続した Neovim で、ファイル引数あり・なし、外部変更の再読込と未保存編集の保護、セッション復元、永続 Undo、画面分割、補完ポップアップ、ファイルツリーを確認しています。Python / Rust / C++ の LSP 接続と保存時 formatter、Rust / C++ のビルド、Python テストも検証済みです。

Python / Rust の Neotest は各 1 テストの成功、Python / Rust / C++ の DAP はサンプル実行から正常終了まで確認しています。Windows のパス区切りによるテスト検出の問題は、公開設定と Windows 用 autocmd で対応しています。Rust の初回テスト操作は rust-analyzer の初期解析が完了してから行ってください。

GitUI / Codex は実ターミナルでバージョン表示の実行、Octo / Diffview はロード、Markdown preview はローカル HTTP 応答まで確認しています。Codex への依頼送信や GitHub への書込みはテストしていません。

## 参考資料

- [LazyVim 標準キー](https://www.lazyvim.org/keymaps)
- [LazyVim 整形設定](https://www.lazyvim.org/plugins/formatting)
- [Blink 補完設定](https://cmp.saghen.dev/configuration/completion)
- [Persistence](https://github.com/folke/persistence.nvim)
- [Terminal の不透明度](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance)
- [Octo](https://github.com/pwntester/octo.nvim)
- [Diffview](https://github.com/sindrets/diffview.nvim)
- [OpenAI 公式 Codex CLI](https://developers.openai.com/codex/cli)
- [GitHub の noreply アドレス](https://docs.github.com/en/account-and-profile/reference/email-addresses-reference)
