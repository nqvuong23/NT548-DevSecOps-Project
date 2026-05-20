## Tạo KMS Key Ring

```
gcloud kms keyrings create vault-key-ring --location global --project nt548-project
```

## Tạo Crypto Key

```
gcloud kms keys create vault-unseal-key --location global --keyring vault-key-ring --purpose encryption --project nt548-project
```

## Tạo GCP Service Account

```
gcloud iam service-accounts create vault-kms-sa --project nt548-project
```

## Cấp quyền KMS

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

## Initialize and unseal one Vault pod

```
kubectl exec vault-0 -n vault -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json

VAULT_UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")

kubectl exec vault-0 -n vault -- vault operator unseal $VAULT_UNSEAL_KEY

kubectl exec vault-0 -n vault -- vault status
```
