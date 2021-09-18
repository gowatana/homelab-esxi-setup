# homelab-esxi-setup

## 0. 事前作業（再インストールの場合）

* ESXi を切断
* クラスタから外す
* vDS からESXiを削除

## 1. インストール

* ESXi をインストール（VMware Workstation の ESXi VM で、USB インストール）

## 2. 初期設定

* DCUI からネットワーク設定。IP / ホスト名 / DNS
* （Workstation ESXi VM でのインストールの場合のみ）
  * ネットワークアダプタのチェックをOFF → 保存
  * ネットワークアダプタのチェックをON（vmk0 MACの重複解消）
* vCenter 登録
* メンテナンス モードに移行

## 3. スクリプト実行

```
PowerCLI> Connect-VIServer -Force infra-vc-01.go-lab.jp
PowerCLI> .\setup_infra-esxi-esxi70u1.ps1 infra-esxi-01.go-lab.jp
```

## 4. 事後作業

* ESXiライセンス割り当て
* クラスタに移動
* メンテナンス モード解除
* vSAN DG / FD 設定
* NSX-T インストール（Transport Node）

以上。
