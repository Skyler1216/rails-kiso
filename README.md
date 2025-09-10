# 環境構築

## 必要なソフトウェア

1. Ruby 3.2.3
2. MySQL 8.0以上
3. Node.js (LTS版)
4. Visual Studio Code
5. Git

上記は必ずインストールした上で始めてください。

## ローカル開発環境のセットアップ

### 1. リポジトリのクローン
```bash
git clone <リポジトリURL>
cd rails-kiso
```

### 2. 依存関係のインストール
```bash
# Rubyのgemをインストール
bundle install

# Node.jsのパッケージをインストール
npm install
```

### 3. データベースのセットアップ
```bash
# MySQLにログインしてユーザーとデータベースを作成
mysql -u root -p

# MySQL内で以下のコマンドを実行
CREATE USER 'user'@'localhost' IDENTIFIED BY 'user';
CREATE DATABASE app_development;
CREATE DATABASE app_test;
CREATE DATABASE app_production;
GRANT ALL PRIVILEGES ON app_development.* TO 'user'@'localhost';
GRANT ALL PRIVILEGES ON app_test.* TO 'user'@'localhost';
GRANT ALL PRIVILEGES ON app_production.* TO 'user'@'localhost';
FLUSH PRIVILEGES;
EXIT;

# Railsでデータベースを作成
bundle exec rails db:create

# マイグレーションを実行
bundle exec rails db:migrate

# シードデータを投入（必要に応じて）
bundle exec rails db:seed
```

### 4. サーバーの起動
```bash
bundle exec rails server
```

ブラウザで `http://localhost:3000` にアクセスして動作を確認してください。

# テスト実行の仕方

必ず上記の環境構築にて、Rails Railway に取り組むための環境を整えてください。

Visual Studio Code を使用してコードを編集し、「TechTrain Railway」という拡張機能から「できた!」と書かれた青いボタンをクリックすると判定が始まります。

詳細にテストを実施したい場合は、下記コマンドの Station 番号を変更し、実行します。

```bash
# Station1のテストをする場合
bundle exec rspec ./spec/station01

# 全テストを実行する場合
bundle exec rspec
```

## 自分のリポジトリの状態を最新の TechBowl-japan/rails-stations と合わせる

Fork したリポジトリは、Fork 元のリポジトリの状態を自動的に反映してくれません。
Station の問題やエラーの修正などがなされておらず、自分で更新をする必要があります。
何かエラーが出た、または運営から親リポジトリを更新してくださいと伝えられた際には、こちらを試してみてください。

### 準備

```shell
# こちらは、自分でクローンした[GitHubユーザー名]/rails-stationsの作業ディレクトリを前提としてコマンドを用意しています。
# 自分が何か変更した内容があれば、 stash した後に実行してください。
git remote add upstream git@github.com:TechBowl-japan/rails-stations.git
git fetch upstream
```

これらのコマンドを実行後にうまくいっていれば、次のような表示が含まれています。

```shell
git branch -a ←このコマンドを実行

* master
  remotes/origin/HEAD -> origin/main
  remotes/origin/main
  remotes/upstream/main ←こちらのような upstream という文字が含まれた表示の行があれば成功です。
```

こちらで自分のリポジトリを TechBowl-japan/rails-stations の最新の状態と合わせるための準備は終了です。

### 自分のリポジトリの状態を最新に更新

```shell
# 自分の変更の状態を stash した上で次のコマンドを実行してください。

# ↓main ブランチに移動するコマンド
git checkout main

# ↓ TechBowl-japan/rails-stations の最新の状態をオンラインから取得
git fetch upstream

# ↓ 最新の状態を自分のリポジトリに入れてローカルの状態も最新へ
git merge upstream/main
git push
npm install
```
