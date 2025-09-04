resource "aws_ses_domain_identity" "this" {
  domain = var.domain_name
}

resource "aws_ses_domain_mail_from" "this" {
  domain                 = aws_ses_domain_identity.this.domain
  mail_from_domain       = "mail.${aws_ses_domain_identity.this.domain}"
  behavior_on_mx_failure = "UseDefaultValue"
}

resource "aws_ses_configuration_set" "this" {
  name                       = "ConfigurationSet"
  reputation_metrics_enabled = true
  sending_enabled            = true

  delivery_options {
    tls_policy = "Require"
  }
}

# Routet53でSESドメイン検証用TXTレコードを設定
resource "aws_route53_record" "ses_verification" {
  zone_id = var.zone_id
  name    = "_amazonses.${aws_ses_domain_identity.this.domain}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.this.verification_token]
}

# ドメイン検証確認用
# Ref: https://registry.terraform.io/providers/hashicorp/awS/6.3.0/docs/resources/ses_domain_identity_verification
resource "aws_ses_domain_identity_verification" "this" {
  domain = aws_ses_domain_identity.this.domain

  depends_on = [aws_route53_record.ses_verification]
}

# Routet53でMXレコードを設定
resource "aws_route53_record" "mx" {
  zone_id = var.zone_id
  name    = "mail.${aws_ses_domain_identity.this.domain}"
  type    = "MX"
  records = ["10 feedback-smtp.ap-northeast-1.amazonses.com"]
  ttl     = 600
}

resource "aws_ses_domain_dkim" "this" {
  domain = aws_ses_domain_identity.this.domain
}

# Route53でDKIMレコードを設定
resource "aws_route53_record" "dkim" {
  count   = 3
  zone_id = var.zone_id
  name    = "${aws_ses_domain_dkim.this.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  records = ["${aws_ses_domain_dkim.this.dkim_tokens[count.index]}.dkim.amazonses.com"]
  ttl     = 600
}

# Route53でSPFレコードを設定
resource "aws_route53_record" "spf" {
  zone_id = var.zone_id
  name    = "mail.${aws_ses_domain_identity.this.domain}"
  type    = "TXT"
  records = ["v=spf1 include:amazonses.com ~all"]
  ttl     = 600
}

# Route53でDMARCレコードを設定
resource "aws_route53_record" "dmarc" {
  zone_id = var.zone_id
  name    = "_dmarc.mail.${aws_ses_domain_identity.this.domain}"
  type    = "TXT"
  records = ["v=DMARC1; p=none; rua=mailto:dmarc@mail.${aws_ses_domain_identity.this.domain}"]
  ttl     = 600
}

resource "aws_ses_template" "set_mfa_required" {
  name    = "SetMFARequired"
  subject = "【Product Name】多要素認証（MFA）が必須に設定されました"

  html = <<HTML
<!doctype html><html lang="ja"><body>
<p>いつもProduct Nameをご利用いただきありがとうございます。<br>
ご利用中の組織の設定にて、<strong>多要素認証（MFA）が必須に設定</strong>されました。</p>
<ul>
<li>すでにMFAを設定済みの方：これまで通り、ご利用中のMFAでログインしてください。</li>
<li>未設定の方：<strong>メールによるワンタイムコード方式（Email MFA）を自動で有効化</strong>しました。次回以降のログイン時に、登録メールアドレス宛に届くコードの入力が必要になります。</li>
</ul>
<h3>次回ログイン手順</h3>
<ol>
<li>ユーザー名／パスワードを入力</li>
<li>登録メールアドレスに届く6桁のコードを確認（有効期限：10分）</li>
<li>ログイン画面でコードを入力して完了</li>
</ol>
<p>今後とも Product Name をよろしくお願いいたします。<br><br>
Organization Name<br>
Product Name<br>
https://www.${var.domain_name}</p>
<hr>
<p style="font-size:12px;color:#666;">本メールアドレスは送信専用となり、返信はお受けしておりません。</p>
</body></html>
HTML

  text = <<TEXT
いつもProduct Nameをご利用いただきありがとうございます。
ご利用中の組織の設定にて、多要素認証（MFA）が必須に設定されました。

- すでにMFAを設定済みの方：これまで通りご利用中のMFAでログインしてください。
- 未設定の方：メールによるワンタイムコード方式（Email MFA）を自動で有効化しました。次回以降のログイン時に、登録メールアドレス宛に届くコードの入力が必要になります。

[次回ログイン手順]
1) ユーザー名／パスワードを入力
2) 登録メールアドレスに届く6桁のコードを確認（有効期限：10分）
3) ログイン画面でコードを入力して完了

今後とも Product Name をよろしくお願いいたします。

Organization Name
Product Name
https://www.${var.domain_name}

-- 
本メールアドレスは送信専用となり、返信はお受けしておりません。
TEXT
}

resource "aws_ses_template" "signup" {
  name    = "SignUp"
  subject = "【Product Name】ユーザー名と仮パスワードをお知らせします"

  html = <<HTML
<!doctype html><html lang="ja"><body>
<p>Product Nameへようこそ。<br><br>
ご登録いただきありがとうございます。<br>
ユーザー名と仮パスワードをお知らせします。</p>
<ol>
<li>ユーザー名：{{user_name}}</li>
<li>仮パスワード：{{temporary_password}}</li>
</ol>
<p>今後とも Product Name をよろしくお願いいたします。<br><br>
Organization Name<br>
Product Name<br>
https://www.${var.domain_name}</p>
<hr>
<p style="font-size:12px;color:#666;">本メールアドレスは送信専用となり、返信はお受けしておりません。</p>
</body></html>
HTML

  text = <<TEXT
Product Nameへようこそ。

ご登録いただきありがとうございます。
ユーザー名と仮パスワードをお知らせします。

- ユーザー名：{{user_name}}
- 仮パスワード：{{temporary_password}}

今後とも Product Name をよろしくお願いいたします。

Organization Name
Product Name
https://www.${var.domain_name}

-- 
本メールアドレスは送信専用となり、返信はお受けしておりません。
TEXT
}
