## Các bước cần làm trước khi deploy Hashicorp Vault (chỉ chạy 1 lần duy nhất)

### Tạo KMS Key Ring

```
gcloud kms keyrings create vault-key-ring --location global --project nt548-project
```

---

### Tạo Crypto Key

```
gcloud kms keys create vault-unseal-key --location global --keyring vault-key-ring --purpose encryption --project nt548-project
```

---

### Tạo GCP Service Account

```
gcloud iam service-accounts create vault-kms-sa --project nt548-project
```

---

### Cấp quyền KMS

```
gcloud kms keys add-iam-policy-binding vault-unseal-key \
  --location global --keyring vault-key-ring \
  --member "serviceAccount:vault-kms-sa@nt548-project.iam.gserviceaccount.com" \
  --role roles/cloudkms.cryptoKeyEncrypterDecrypter \
  --project nt548-project

# Bind Workload Identity
gcloud iam service-accounts add-iam-policy-binding \
  vault-kms-sa@nt548-project.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:nt548-project.svc.id.goog[vault/vault]" \
  --project nt548-project

gcloud kms keys add-iam-policy-binding vault-unseal-key \
  --location global \
  --keyring vault-key-ring \
  --member "serviceAccount:vault-kms-sa@nt548-project.iam.gserviceaccount.com" \
  --role roles/cloudkms.viewer \
  --project nt548-project
```

---

## Cấu hình để sử dụng Hashicorp Vault

### Initialize and unseal one Vault pod

```
kubectl exec vault-0 -n vault -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json

VAULT_UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")

kubectl exec vault-0 -n vault -- vault operator unseal $VAULT_UNSEAL_KEY

kubectl exec vault-0 -n vault -- vault status
```

---

### Đăng nhập vào Hashicorp Vault Web UI

Sử dụng `root_token` trong file `cluster-keys.json` (được tạo ra từ bước cấu hình trên) để đăng nhập.

---

### Tạo Secret

- **Bước 1**: Ở menu chính, chọn **Secrets Engines** > Nhấn **Enable new engine**.
- **Bước 2**: Chọn **KV** (Key-Value).
- **Bước 3**: Ở ô Path, nhập tên secret engine `devsecops_nhom10` > Chọn Version 2 > Nhấn **Enable Engine**.
- **Bước 4** (Tạo các secret): Nhấn vào secret engine vừa tạo > Chọn **Create secret** và tạo lần lượt các secrets sau:
  - Path = `sonarqube`: Key = `token` - Value = `<token lấy được khi tạo bên SonarQube Web UI>`
  - Path = `harbor`: Key = `username` - Value = `<Name của Harbor Robot Account>`, Key = `password` - Value = `<Secret của Harbor Robot Account>` 
  - Path = `argocd`: Key = `token` - Value = `<Token của ArgoCD>`
  - Nhấn Save.

---

### Bật tính năng AppRole (Auth Method)

1. Trên thanh menu chính của Web UI, chọn tab **Access** > **Chọn Authentication Methods**.
2. Nhấn nút **Enable new method**.
3. Tìm và chọn **AppRole** trong danh sách.
4. Ở ô **Path**, Vault sẽ tự điền là approle (cứ để mặc định) > Nhấn **Enable Method**.

---

### Tạo Chính sách (Policy) cho Jenkins

1. Chuyển sang tab **Policies** trên menu chính.
2. Nhấn nút **Create ACL policy**.
3. Điền thông tin:
  - Name: Nhập `jenkins-policy`
  - Policy: Copy và dán đoạn code phân quyền phía dưới vào khung cấu hình

```
path "devsecops_nhom10/data/sonarqube" {
  capabilities = ["read"]
}
path "devsecops_nhom10/data/harbor" {
  capabilities = ["read"]
}
path "devsecops_nhom10/data/argocd" {
  capabilities = ["read"]
}
```

4. Kéo xuống dưới cùng và nhấn **Create policy**.

---

### Tạo và cấu hình AppRole cho Jenkins

1. Trên góc trên bên trái của menu chính, nhấn vào biểu tượng CLI.
2. Copy và paste lệnh sau vào cái ô đen đó rồi nhấn Enter:

```
# Tạo Role tên jenkins-role và gắn policy jenkins-policy vào
vault write auth/approle/role/jenkins-role token_policies="jenkins-policy"
```

---

### Lấy RoleID và SecretID từ Web UI để điền vào Jenkins

Vẫn dùng CLI trên Web UI, nhập 2 lệnh sau để lấy RoleID và SecretID:

```
# Lấy RoleID (Cần lưu lại để cấu hình vào Jenkins)
vault read auth/approle/role/jenkins-role/role-id

# Tạo và lấy SecretID (Cần lưu lại, cái này cần bảo mật)
vault write -f auth/approle/role/jenkins-role/secret-id
```
