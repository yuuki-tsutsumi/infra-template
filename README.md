# infra-template

## 実績のある動作環境

- OS: mac

## 前提

- `make` と `docker-compose` がインストール済みであること

## AWSリソースの設定変更手順
AWSリソースの設定する場合は、Terraformコードの修正を該当のファイル（例：`accounts/staging/cognito/main.tf`）に対して行ってください。

設定変更後は、必ずプルリクエストを作成してレビュー・マージしてください。
マージされると、CI/CDパイプラインが自動で実行され、ステージング環境に設定が反映されます。
ローカル端末からのterraform apply実行は原則禁止です。

## 環境構築

1. **.env.exampleを元に.envを作成**

    ```bash
    $ cp .env.example .env
    ```

    envに実際の値を入力してください。

2. **コンテナ立ち上げとコンテナ内への入り方**

    ```bash
    $ make up
    $ make enter
    ```

3. **Terraform初期化**
    ステージング環境の場合は以下です。
    ```bash
    $ cd accounts/staging/
    $ terraform init
    ```

4. **フォーマット確認**
    Terraform のフォーマットを確認する場合、以下のコマンドを実行します。
    ```bash
    $ terraform fmt -recursive -check
    ```

5. **Terraform Planでの変更内容確認**
    Terraform での変更内容を確認する場合、以下のコマンドを実行します。
    ```bash
    $ terraform plan
    ```

## 注意事項
- ファイルの最終行は改行を入れてください。IDEの設定を入れておくのが推奨です。

    VSCodeでの設定例
    ```
    {
      "files.insertFinalNewline": true,
      "files.trimFinalNewlines": true
    }
    ```

- Terraformで管理するタグについては、Terraform:true タグを仕様でタグをつけられない場合を除き付与してください。
