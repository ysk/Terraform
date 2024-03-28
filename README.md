# Terraformの構成一覧

## ec2-MultiAZ
EC2をプライベートサブネットに配置<br>
インスタンスへの接続はSSMで行う。<br>

## ec2-SingleAZ

EC2をパブリックサブネットに配置する。<br>
簡易的なテストをする時以外は使用しない。<br>
インスタンスへの接続はSSMで行う。

## ec2_rds-SingleAZ

ec2-SingleAZと同様、EC2をパブリックサブネットに配置する。<br>
簡易的なテストをする時以外は使用しない。<br>
インスタンスへの接続はSSMで行う。

## ecs_fargate_rds-MultiAZ

ECS on Fargete構成の学習用で使用している。<br>
FargeteへのSSMへのログインの実装などが残タスクとしてある。

## eks-MultiAZ

学習用。<br>
Kubernetesを使った構成について学ぶ。


## s3_cloudfront

CloudFront+S3構成のサイトを実装する際に使う。<br>
デプロイはGitHub Actionsで行う想定。<br>
残タスクとしてGitHub Actionsの設定のセキュリティ向上などがある。

下記のようなエラーが表示される場合がある
```
Error: Provider configuration not present
```
providersの確認
```
terraform providers
```
Multi-AZ配置とSingle-AZ
プロバイダーの置換

```
terraform state replace-provider 'registry.terraform.io/-/aws' 'registry.terraform.io/hashicorp/aws'
```

参考サイト<br>
https://qiita.com/kinchiki/items/215e1387b040b3118d96
