# Omaterm

**[English](README.md) | 日本語**

DHH による Omakase ターミナルセットアップ。[Omarchy](https://omarchy.org) のヘッドレス版とでも言うべきものです。

> **コミュニティメンテナンスのフォークです。** 上流の `omacom/omaterm` は2026年に引退・アーカイブされました（[上流の引退通知](https://omarchy.org/server)を参照）。本フォークでは、引退済みの upstream イメージを pull する代わりに Docker イメージをローカルでビルドすることで、インストール可能な状態を維持しています。

## セットアップされるもの

- **シェル**: Bash（starship プロンプト、fzf、eza、zoxide、tmux）
- **エディタ**: Neovim（LazyVim）
- **エージェント**: opencode、claude-code、codex、gemini
- **開発ツール**: mise、docker、GitHub CLI（`gh`）、1Password CLI（`op`）、lazygit、lazydocker、hunk
- **ネットワーク**: SSH、tailscale
- **Git**: ユーザー名/メールの対話的設定、便利なエイリアス

コアのシステムパッケージや Neovim・tmux・Starship・eza・gum・GitHub CLI・1Password CLI・lazygit・lazydocker といったユーザーフェースなツールは、Docker イメージ内の Arch パッケージとしてインストールされます。AI ツール群は OS パッケージの後に mise 経由でインストールされます。

## インストール

Docker 経由で Omaterm をインストールします。

```bash
curl -fsSL https://raw.githubusercontent.com/okki-at-zero/omaterm/master/install.sh | bash
```

Arch、Debian/Ubuntu、Fedora では、Docker のインストールと有効化も行います。WSL では、WSL 統合が有効な Docker Desktop がすでにインストール・起動している必要があります。

`omaterm` を実行して開始します。

### イメージ

Omaterm は `omaterm:local` というローカルビルドのイメージで動作します。最初に `omaterm` を実行すると、インストーラが `~/.local/share/omaterm/src` に展開したソースチェックアウトからイメージがビルドされ、以後は再利用されます。ビルドは認証情報なしでも動作します。`gh`・`GITHUB_TOKEN`・`GH_TOKEN` で GitHub トークンを与えると GitHub API のレート制限を回避できます。

環境変数:

```bash
OMATERM_IMAGE=ghcr.io/okki-at-zero/omaterm  # 別イメージで動かす（通常の Docker イメージとして pull される）
OMATERM_SRC=/path/to/src  # ローカルビルドに使うソースチェックアウト
OMATERM_REPO=you/omaterm  # インストーラが取得するリポジトリ（デフォルト: このフォーク）
OMATERM_REF=my-branch     # インストーラが取得するブランチ（デフォルト: master）
```

## セットアップ

セットアップ引数が与えられない場合、Omaterm は通常の対話的質問を開始します。セットアッププロンプトで Ctrl+C を押すと、残りのセットアップをスキップできます。

名前付き Omaterm の作成時に初回セットアップを直接埋め込むこともできます:

```bash
omaterm new omaterm2 \
  --git-name "Your Name" \
  --git-email you@example.com \
  --gh-token ghp_... \
  --ts-token tskey-auth-... \
  --ts-host my-omaterm \
  --op-token ops_... \
  --ssh-key "ssh-ed25519 AAAAC3..."
```

いずれかのセットアップ引数が与えられると、指定された値を適用して対話プロンプトなしでセットアップを終了します。すべての値をコマンドラインで渡す代わりに、1Password のアイテムのトップレベルフィールドに保存して、Omaterm をそのアイテムに向けることもできます:

```bash
omaterm new omaterm2 --op "Omaterm Setup"
```

Omaterm は `git-name`・`git-email`・`gh-token`・`ts-token`・`ts-host`・`op-token`・`ssh-key` という名前のフィールドを読み取ります。コマンドラインの直接指定は 1Password アイテムのフィールドより優先されます。セットアップ値はコンテナの初回作成時のみ適用され、既存の `omaterm` コンテナは元の環境とホームディレクトリの状態を保ちます。

こうして埋め込んだトークンはコンテナの寿命の間、その環境変数に保持されます — ホストへの Docker アクセスを持つ誰でも `docker inspect` で読めますし、`omaterm template create` はテンプレートイメージにそれらを焼き込みます。スコープを絞った、失効可能なトークンを使ってください。

## 管理

インストールされた `omaterm` コマンドで、再接続・追加の名前付き Omaterm 作成・削除を行います:

```bash
omaterm
omaterm connect omaterm2
omaterm new omaterm2
omaterm new omaterm2 -d # ホストの Docker エンジンをマウント
omaterm new omaterm2 --docker-access # -d のロングフォーム
omaterm new worker1 --detach # ヘッドレス起動: ターミナル無し、`omaterm exec` のために待機
omaterm exec omaterm2 -w /home/omaterm/Work/project 'docker ps'
omaterm ls
omaterm rm omaterm2
omaterm rm -a
```

1つの Omaterm を思い通りにセットアップしたら、再利用可能なテンプレートとしてキャプチャして、そこから素早く新しい箱を量産できます:

```bash
omaterm template create ruby --from omaterm2 # 1回だけのスナップショット（遅い、箱をコピー）
omaterm new dev1 --template ruby             # 即時 — テンプレートから起動
omaterm new dev2 -t ruby --ts-token tskey-... # 箱ごとに独自の Tailscale ノードを登録
omaterm template ls                          # テンプレート一覧
omaterm template rm ruby                     # テンプレート削除
```

`template create` は箱のスナップショットを一度だけ取ります。その後の各 `new --template` はほぼ即時のコピー・オン・ライトの複製です。テンプレートから作られた各箱は、生成元とアイデンティティを奪い合わず、それぞれが新しい Tailscale ノードを登録します。焼き込まれたツール・パッケージ・git 設定は引き継がれます。

`--ts-host` を指定せずに `--ts-token` を渡すと、Tailscale のホスト名は `<host>-<name>` になります — 例: ホスト `dhh-fd` 上で `bokka-bc3` を作ると `dhh-fd-bokka-bc3` として登録されます。名前を明示したい場合は `--ts-host` を渡してください。

通常の Omaterm は対話的に起動し、ログインシェルによって保ちられます。`--detach` を付けるとヘッドレスで起動します: ターミナルはアタッチされず PID 1 として待機するので、`omaterm exec`・スーパーバイザ・後からの `omaterm connect`（起動中の箱内に新しいログインシェルを開く）で使えます。

名前付きコンテナは再起動間でもファイルシステムを持ち越します（ホームディレクトリの状態・インストール済みパッケージ・git 設定・シェル履歴・プロジェクトを含む）。シェル環境をリセットしたいときは `docker rm omaterm` で Omaterm コンテナを削除します。Omaterm はホストネットワークを使うので、コンテナがホストの localhost に公開するサービスは Omaterm の中からも到達できます。`omaterm new NAME -d` または `omaterm new NAME --docker-access` で `/var/run/docker.sock` 経由でホストの Docker エンジンをマウントできます。

## リソース制限

複数の Omaterm が1台のマシンを共有してもホストや相互を饿死させないように、すべての Omaterm は CPU・メモリ制限付きで起動され、作成・削除のたびに再分配されます:

- **ホスト予約**: ホストが負荷下でも応答を保てるよう、1コアと2GBのRAMを確保します
- **CPU（分割）**: 残りのコアは互いに重複しない連続集合に分割され、1つの Omaterm に1つずつ割り当てられます。そのため別の Omaterm 内のワーカーが同じコアに載ることはありません。単独の Omaterm は予約分以外のすべてのコアを得て、Omaterm の増減に応じて再分割されます。分配できないほど Omaterm が多い場合は、全 Omaterm が非予約レンジ全体に固定され、`cpu-shares` で比重が決められます
- **メモリ（分割）**: 残りのRAMは全 Omaterm で均等に固定分割され（`(TOTAL_RAM - 2 GB) / 個数`）、スワップは無効なので、ある Omaterm がマシン全体をスワップに巻き込んだり他を OOM させたりしません

環境変数で調整・無効化できます:

```bash
OMATERM_HOST_RESERVE_CORES=2 omaterm new ci   # ホストに2コア予約
OMATERM_HOST_RESERVE_RAM_MB=4096 omaterm new ci  # ホストに4GB予約
OMATERM_CPU_SHARES=512 omaterm new ci         # この配置に別の比重を与える
OMATERM_NO_LIMITS=1 omaterm new ci            # 制限を完全に無効化
```

`omaterm new NAME --no-limits`（`-n`）で特定の Omaterm を丸ごと除外できます: 制限なしで動き、すべての分配・再バランスから外れるので、他の Omaterm 同士だけでホストを分け合います。

こうして設定した CPU・メモリ制限は、起動中の Omaterm に `docker update` で調整することもできます。コンテナに焼き込まれた環境変数は調整できません。
