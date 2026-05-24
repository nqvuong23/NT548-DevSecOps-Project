## Cấu hình để sử dụng Harbor

### Login vào Harbor Web UI

username: `admin`
password: `admin`

---

### Tạo Private Project

- Vào tab **Projects**
- Click **New Project**
- Nhập: 
    - Project Name: `devsecops_nhom10`
    - Access Level: Không click chọn **Public** (vì dùng Private Repository)
    - Project quota limits: `-1` (Không giới hạn quota)
    - Proxy Cache: Không `Enable`
- Nhấn **OK**

---

### Tạo Robot Account cho Jenins/ArgoCD sử dụng

- Vào tab **Projects**
- Chọn project `devsecops_nhom10`
- Chọn tab **Robot Accounts**
- Click **New Robot Account**
- Nhập:
    - Name: `jenkins`
    - Expiration: chọn `Never Expired`
- Nhấn **Next**
- Chọn quyền:
    - Pull Repository 
    - Push Repository 
- Click **Save**
  
**⚠️ Cực kỳ quan trọng**: Sau khi tạo xong, Harbor sẽ hiển thị 1 lần duy nhất **Username** và **Secret (Password)** 👉 Click **Export to File** hoặc copy lại.
