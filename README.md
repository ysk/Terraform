terraformのテスト
# Terraformの構成一覧

## ec2_only

EC2をパブリックサブネットに配置する。シングル構成。<br>
簡易的なテストをする時以外は使用しない。
インスタンスへの接続はSSMで行う。


## ec2_rds

ec2_onlyと同様、EC2をパブリックサブネットに配置する。シングル構成。<br>
簡易的なテストをする時以外は使用しない。
インスタンスへの接続はSSMで行う。

## ecs_fargate_rds

ECS on Fargete構成の学習用で使用している。
FargeteへのSSMへのログインの実装などが残タスクとしてある。


## s3_cloudfront

CloudFront+S3構成のサイトを実装する際に使う想定。


下記のようなエラーが表示される場合がある
```
Error: Provider configuration not present
```
providersの確認
```
terraform providers
```

プロバイダーの置換

```
terraform state replace-provider 'registry.terraform.io/-/aws' 'registry.terraform.io/hashicorp/aws'
```

参考サイト<br>
https://qiita.com/kinchiki/items/215e1387b040b3118d96