pipeline {
    // =========================================================================
    // Pod Template: Dynamic Agent chạy trên platform-pool
    // Bao gồm tất cả container cần thiết cho toàn bộ pipeline DevSecOps
    // =========================================================================
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: jenkins-agent
spec:
  # Ép Pod Agent chạy vào platform-pool theo thiết kế hệ thống
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: pool
            operator: In
            values:
            - platform
  # Cần Toleration vì node pool này có Taint "NoSchedule"
  tolerations:
  - key: "pool"
    operator: "Equal"
    value: "platform"
    effect: "NoSchedule"

  volumes:
  # Shared emptyDir volume để truyền Harbor docker config.json tới Kaniko
  # Kaniko đọc credentials tại /kaniko/.docker/config.json
  - name: kaniko-docker-config
    emptyDir: {}

  containers:
  # Container JNLP mặc định để kết nối với Jenkins Controller
  - name: jnlp
    image: jenkins/inbound-agent:3256.v88a_f6e922152-1-jdk21

  # Container Gitleaks để quét Secret (Task 2.2)
  - name: gitleaks
    image: zricethezav/gitleaks:v8.18.2
    command: [sleep]
    args: [infinity]

  # Container SonarQube Scanner để phân tích SAST (Task 2.3)
  - name: sonar-scanner
    image: sonarsource/sonar-scanner-cli:5
    command: [sleep]
    args: [infinity]

  # Container Checkov để quét IaC (Task 2.3)
  - name: checkov
    image: bridgecrew/checkov:3.2.111
    command: [sleep]
    args: [infinity]

  # Container Trivy để quét SCA + Image Scan (Task 2.3 & 2.4)
  - name: trivy
    image: aquasec/trivy:0.50.1
    command: [sleep]
    args: [infinity]

  # Container Kaniko để Build & Push Image lên Harbor (Task 2.4)
  # Không cần privileged mode — đây là lý do dùng Kaniko thay Docker-in-Docker
  - name: kaniko
    image: gcr.io/kaniko-project/executor:v1.23.2-debug
    command: [sleep]
    args: [infinity]
    volumeMounts:
    - name: kaniko-docker-config
      mountPath: /kaniko/.docker

  # Container kubectl + yq + argocd-cli để Update Helm & Trigger ArgoCD (Task 2.4)
  # Cũng dùng để chuẩn bị Harbor docker config.json cho Kaniko
  - name: tools
    image: alpine/k8s:1.28.3
    command: [sleep]
    args: [infinity]
    env:
    - name: HOME
      value: /root
    volumeMounts:
    - name: kaniko-docker-config
      mountPath: /kaniko/.docker
"""
        }
    }

    // =========================================================================
    // Biến môi trường dùng xuyên suốt pipeline
    // =========================================================================
    environment {
        // Harbor Registry
        HARBOR_REGISTRY    = "harbor.vuongdevops.io.vn"
        HARBOR_PROJECT     = "devsecops_nhom10"

        // Git repo để update Helm values (GitOps)
        GIT_REPO_URL       = "https://github.com/${env.GIT_URL?.tokenize('/')[-2]}/${env.GIT_URL?.tokenize('/')[-1]?.replace('.git','')}"
        GIT_USER_NAME      = "Jenkins Pipeline"
        GIT_USER_EMAIL     = "jenkins@vuongdevops.io.vn"

        // ArgoCD
        ARGOCD_SERVER      = "argocd.vuongdevops.io.vn"
        ARGOCD_APP_NAME    = "online-boutique"

        // Image tag dùng Git commit SHA (7 ký tự đầu)
        IMAGE_TAG          = "${env.GIT_COMMIT?.take(7) ?: 'latest'}"
    }

    stages {
        // =====================================================================
        // STAGE 1: Git Checkout
        // =====================================================================
        stage('Git Checkout') {
            steps {
                checkout scm
                script {
                    // Lấy commit SHA sau khi checkout để đảm bảo chính xác
                    env.IMAGE_TAG = sh(script: 'git rev-parse --short=7 HEAD', returnStdout: true).trim()
                    env.GIT_BRANCH_NAME = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                    env.CHANGED_FILES = sh(script: 'git diff --name-only HEAD~1 HEAD 2>/dev/null || git diff --name-only HEAD 2>/dev/null || echo ""', returnStdout: true).trim()
                    echo ">>> Branch: ${env.GIT_BRANCH_NAME} | Image Tag: ${env.IMAGE_TAG} | Changed Files: ${env.CHANGED_FILES}"
                }
            }
        }

        // =====================================================================
        // STAGE 2: Secret Scanning (Gitleaks) - Task 2.2
        // =====================================================================
        stage('Secret Scanning - Gitleaks') {
            steps {
                container('gitleaks') {
                    script {
                        echo ">>> Đang bắt đầu quét Secret bằng Gitleaks..."
                        def exitCode = sh(
                            script: 'gitleaks detect --no-git --source ./app_src --config .gitleaks.toml --verbose --report-format json --report-path gitleaks-report.json',
                            returnStatus: true
                        )
                        if (exitCode == 1) {
                            error "Gitleaks phát hiện secret! Xem file gitleaks-report.json trong Artifacts để biết chi tiết."
                        } else if (exitCode != 0) {
                            error "Gitleaks lỗi không xác định, exit code: ${exitCode}."
                        }
                        echo ">>> Không phát hiện secret bị lộ."
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
                }
            }
        }

        // =====================================================================
        // STAGE 3: SAST - SonarQube Analysis - Task 2.3
        // Lấy SonarQube token từ Vault thay vì Jenkins credential
        // =====================================================================
        stage('SAST - SonarQube') {
            steps {
                container('sonar-scanner') {
                    withVault(vaultSecrets: [
                        [
                            path: 'devsecops_nhom10_kv/sonarqube',
                            engineVersion: 2,
                            secretValues: [
                                [envVar: 'SONAR_TOKEN', vaultKey: 'token']
                            ]
                        ]
                    ]) {
                        script {
                            echo ">>> Đang bắt đầu phân tích mã nguồn với SonarQube..."
                            withSonarQubeEnv(installationName: 'sonarqube-server') {
                                sh 'sonar-scanner -Dsonar.token=$SONAR_TOKEN'
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // STAGE 4: Quality Gate Check - Task 2.3
        // =====================================================================
        stage('Quality Gate Check') {
            steps {
                container('sonar-scanner') {
                    withVault(vaultSecrets: [
                        [
                            path: 'devsecops_nhom10_kv/sonarqube',
                            engineVersion: 2,
                            secretValues: [
                                [envVar: 'SONAR_TOKEN', vaultKey: 'token']
                            ]
                        ]
                    ]) {
                        withSonarQubeEnv(installationName: 'sonarqube-server') {
                            script {
                                echo ">>> Đang chờ kết quả Quality Gate từ SonarQube..."

                                // Lấy task ID từ file report-task.txt do sonar-scanner tạo ra
                                def taskId = sh(
                                    script: "grep 'ceTaskId=' .scannerwork/report-task.txt | cut -d'=' -f2",
                                    returnStdout: true
                                ).trim()
                                echo ">>> Polling task ID: ${taskId}"

                                // Chờ SonarQube xử lý xong task phân tích (tối đa 10 phút)
                                timeout(time: 10, unit: 'MINUTES') {
                                    waitUntil(initialRecurrencePeriod: 10000) {
                                        def taskStatus = sh(
                                            script: """
                                                curl -sf -u "\${SONAR_TOKEN}:" "\${SONAR_HOST_URL}/api/ce/task?id=${taskId}" \
                                                  | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4
                                            """,
                                            returnStdout: true
                                        ).trim()
                                        echo ">>> Task processing status: ${taskStatus}"
                                        return taskStatus in ['SUCCESS', 'FAILED', 'CANCELLED', 'ERROR']
                                    }
                                }

                                // Kiểm tra kết quả Quality Gate sau khi task xử lý xong
                                def qgStatus = sh(
                                    script: """
                                        curl -sf -u "\${SONAR_TOKEN}:" "\${SONAR_HOST_URL}/api/qualitygates/project_status?projectKey=DevSecOps_Nhom10" \
                                          | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4
                                    """,
                                    returnStdout: true
                                ).trim()

                                echo ">>> Quality Gate status: ${qgStatus}"
                                if (qgStatus != 'OK') {
                                    error "Pipeline bị hủy vì không vượt qua được SonarQube Quality Gate! Trạng thái: ${qgStatus}"
                                }
                                echo ">>> Quality Gate PASSED!"
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // STAGE 5: IaC Scan - Checkov - Task 2.3
        // =====================================================================
        stage('IaC Scan - Checkov') {
            steps {
                container('checkov') {
                    script {
                        echo ">>> Đang bắt đầu quét mã nguồn Terraform bằng Checkov..."
                        def exitCode = sh(
                            script: 'checkov -d ./terraform -o json > checkov-report.json',
                            returnStatus: true
                        )
                        if (exitCode != 0) {
                            echo ">>> CẢNH BÁO: Checkov phát hiện rủi ro IaC hoặc có lỗi xảy ra (exit code: ${exitCode})! Xem checkov-report.json."
                        } else {
                            echo ">>> Không phát hiện rủi ro IaC nào."
                        }
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'checkov-report.json', allowEmptyArchive: true
                }
            }
        }

        // =====================================================================
        // STAGE 6: SCA - Trivy Dependency Scan - Task 2.3
        // =====================================================================
        stage('SCA - Trivy Dependency Scan') {
            steps {
                container('trivy') {
                    script {
                        echo ">>> Đang bắt đầu quét Dependency bằng Trivy..."
                        def exitCode = sh(
                            script: 'trivy fs --format json --output trivy-fs-report.json --exit-code 1 --severity HIGH,CRITICAL ./app_src',
                            returnStatus: true
                        )
                        if (exitCode != 0) {
                            echo ">>> CẢNH BÁO: Trivy phát hiện lỗ hổng mức độ HIGH/CRITICAL trong Dependency! Xem trivy-fs-report.json."
                        } else {
                            echo ">>> Không phát hiện lỗ hổng nghiêm trọng nào trong Dependency."
                        }
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-fs-report.json', allowEmptyArchive: true
                }
            }
        }

        // =====================================================================
        // STAGE 7: Build & Push Docker Images via Kaniko - Task 2.4
        //
        // Kaniko là công cụ build image không cần Docker daemon và không cần
        // privileged mode — phù hợp cho môi trường Kubernetes.
        //
        // Quy trình:
        //   1. Lấy Harbor credentials từ Vault (trong container 'tools').
        //   2. Ghi /kaniko/.docker/config.json vào shared emptyDir volume —
        //      đây là best practice để truyền credentials cho Kaniko mà không
        //      expose chúng trên command line hay biến môi trường.
        //   3. Kaniko đọc config.json, build image từ Dockerfile và push
        //      thẳng lên Harbor trong một lệnh duy nhất.
        //
        // QUAN TRỌNG: Kaniko executor thoát ra sau mỗi lần build, do đó
        //   không thể gọi nhiều lệnh sh riêng lẻ trong cùng một container
        //   block. Giải pháp: xây dựng một shell script duy nhất chứa toàn
        //   bộ các lệnh kaniko và chạy trong một sh call.
        // =====================================================================
        stage('Build & Push Images via Kaniko') {
            steps {
                // Bước 1: Lấy credentials từ Vault và ghi docker config.json
                // vào shared volume để Kaniko có thể đọc khi xác thực với Harbor.
                // Thực hiện trong container 'tools' (có shell đầy đủ).
                container('tools') {
                    withVault(vaultSecrets: [
                        [
                            path: 'devsecops_nhom10_kv/harbor',
                            engineVersion: 2,
                            secretValues: [
                                [envVar: 'HARBOR_USER', vaultKey: 'username'],
                                [envVar: 'HARBOR_PASS', vaultKey: 'password']
                            ]
                        ]
                    ]) {
                        script {
                            echo ">>> Chuẩn bị Harbor credentials cho Kaniko..."

                            // Tạo docker config.json dạng base64 auth token
                            // Best practice: dùng printf thay echo để tránh newline,
                            // ghi vào shared volume /kaniko/.docker/config.json
                            sh '''
                                mkdir -p /kaniko/.docker
                                AUTH_B64=$(printf "%s:%s" "${HARBOR_USER}" "${HARBOR_PASS}" | base64 | tr -d '\\n')
                                cat > /kaniko/.docker/config.json <<EOF
{
  "auths": {
    "${HARBOR_REGISTRY}": {
      "auth": "${AUTH_B64}"
    }
  }
}
EOF
                                echo ">>> docker config.json đã được tạo tại /kaniko/.docker/config.json"
                                # Kiểm tra file tồn tại (không in nội dung để bảo mật)
                                ls -la /kaniko/.docker/config.json
                            '''
                        }
                    }
                }

                // Bước 2: Kaniko build & push từng microservice lên Harbor
                //
                // FIX: Kaniko executor process thoát ra (exit) sau mỗi lần
                // build xong. Nếu gọi sh() nhiều lần trong cùng container
                // block, Jenkins sẽ báo lỗi "Process exited immediately after
                // creation" từ lần build thứ 2 trở đi vì shell trong container
                // không còn tồn tại.
                //
                // Giải pháp: Xây dựng toàn bộ các lệnh kaniko thành một
                // chuỗi script duy nhất trong Groovy, sau đó thực thi bằng
                // một sh() call duy nhất — Kaniko chạy tuần tự từng lệnh
                // trong cùng một shell process.
                container('kaniko') {
                    script {
                        echo ">>> Đang build & push Docker Images bằng Kaniko với tag: ${IMAGE_TAG}..."

                        // Danh sách các microservice cần build
                        def services = [
                            'adservice',
                            'cartservice',
                            'checkoutservice',
                            'currencyservice',
                            'emailservice',
                            'frontend',
                            'productcatalogservice',
                            'recommendationservice',
                            'shippingservice'
                        ]

                        // Xây dựng script shell tổng hợp — tất cả lệnh kaniko
                        // được nối vào một chuỗi và chạy trong một sh() duy nhất.
                        // Điều này đảm bảo container shell process không thoát
                        // giữa các lần build.
                        def buildScript = '#!/busybox/sh\nset -e\n'

                        // Track service nào thực sự được build để Stage 9 (GitOps)
                        // chỉ cập nhật tag của đúng service đó trong values.yaml.
                        def builtServices = []

                        services.each { svc ->
                            def dockerfilePath = "app_src/${svc}/Dockerfile"

                            if (env.CHANGED_FILES.contains("app_src/${svc}") || env.CHANGED_FILES.isEmpty()) {
                                if (fileExists(dockerfilePath)) {
                                    def imageFull   = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${svc}:${IMAGE_TAG}"
                                    def imageLatest = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${svc}:latest"

                                    // Đánh dấu service này sẽ được build & push
                                    builtServices.add(svc)

                                    buildScript += """
echo '>>> Building & Pushing: ${imageFull}'
/kaniko/executor \\
  --context      \$(pwd)/app_src/${svc} \\
  --dockerfile   \$(pwd)/${dockerfilePath} \\
  --destination  ${imageFull} \\
  --destination  ${imageLatest} \\
  --cache=true \\
  --cache-repo   ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/cache_v3 
echo '>>> Kaniko đã build và push thành công: ${imageFull}'
"""
                                } else {
                                    buildScript += "echo '>>> Bỏ qua ${svc}: không tìm thấy Dockerfile tại ${dockerfilePath}'\n"
                                }
                            } else {
                                buildScript += "echo '>>> Bỏ qua ${svc}: không có thay đổi'\n"
                            }
                        }

                        buildScript += "echo '>>> Build & Push hoàn tất! Image tag: ${IMAGE_TAG}'\n"

                        // Lưu danh sách service đã build vào env var để Stage 9 dùng
                        env.BUILT_SERVICES = builtServices.join(',')
                        echo ">>> Services đã build & push: ${builtServices.join(', ') ?: 'không có service nào'}"

                        // Thực thi toàn bộ script trong một sh() call duy nhất
                        sh(script: buildScript)
                    }
                }
            }
        }

        // =====================================================================
        // STAGE 8: Image Scan - Trivy - Task 2.4
        // Quét image trực tiếp từ Harbor Registry sau khi Kaniko đã push xong.
        // Trivy tự authenticate với Harbor qua --username / --password.
        // =====================================================================
        stage('Image Scan - Trivy') {
            steps {
                container('trivy') {
                    withVault(vaultSecrets: [
                        [
                            path: 'devsecops_nhom10_kv/harbor',
                            engineVersion: 2,
                            secretValues: [
                                [envVar: 'HARBOR_USER', vaultKey: 'username'],
                                [envVar: 'HARBOR_PASS', vaultKey: 'password']
                            ]
                        ]
                    ]) {
                        script {
                            echo ">>> Đang bắt đầu quét Docker Image bằng Trivy (từ Harbor Registry)..."

                            def services = [
                                'adservice', 'cartservice', 'checkoutservice',
                                'currencyservice', 'emailservice', 'frontend',
                                'paymentservice', 'productcatalogservice',
                                'recommendationservice', 'shippingservice'
                            ]

                            def failedServices = []

                            services.each { svc ->
                                if (env.CHANGED_FILES.contains("app_src/${svc}") || env.CHANGED_FILES.isEmpty()) {
                                    def imageFull = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${svc}:${IMAGE_TAG}"
                                    if (fileExists("app_src/${svc}/Dockerfile")) {
                                        echo ">>> Scanning image: ${imageFull}"
                                        def exitCode = sh(
                                            script: """
                                                trivy image \\
                                                  --insecure \\
                                                  --username "\${HARBOR_USER}" \\
                                                  --password "\${HARBOR_PASS}" \\
                                                  --format json \\
                                                  --output trivy-image-${svc}-report.json \\
                                                  --exit-code 1 \\
                                                  --severity HIGH,CRITICAL \\
                                                  --ignore-unfixed \\
                                                  ${imageFull}
                                            """,
                                            returnStatus: true
                                        )
                                        if (exitCode != 0) {
                                            failedServices.add(svc)
                                            echo ">>> CẢNH BÁO: ${svc} có lỗ hổng HIGH/CRITICAL!"
                                        }
                                    } else {
                                        echo ">>> Bỏ qua quét Trivy cho ${svc}: không tìm thấy Dockerfile"
                                    }
                                } else {
                                    echo ">>> Bỏ qua quét Trivy cho ${svc}: không có thay đổi"
                                }
                            }

                            if (failedServices) {
                                echo ">>> CẢNH BÁO: Trivy phát hiện lỗ hổng HIGH/CRITICAL trong: ${failedServices.join(', ')}. Xem report để biết chi tiết."
                            } else {
                                echo ">>> Tất cả Docker Image đều an toàn!"
                            }
                        }
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-image-*-report.json', allowEmptyArchive: true
                }
            }
        }

        // =====================================================================
        // STAGE 9: GitOps - Update values.yaml & Trigger ArgoCD Auto-Sync
        // =====================================================================
        stage('GitOps - Update Image Tag & Push') {
            steps {
                container('tools') {
                    withCredentials([sshUserPrivateKey(
                        credentialsId  : 'ssh-private-key',
                        keyFileVariable: 'SSH_KEY_FILE',
                        usernameVariable: 'SSH_USERNAME'
                    )]) {
                        script {
                            // Đọc danh sách service đã được build từ Stage 7
                            def builtServices = env.BUILT_SERVICES
                                ? env.BUILT_SERVICES.split(',').toList()
                                : []

                            if (builtServices.isEmpty()) {
                                echo ">>> [GitOps] Không có service nào được build/push trong pipeline này. Bỏ qua cập nhật values.yaml."
                                return
                            }

                            echo ">>> [GitOps] Sẽ cập nhật tag=${IMAGE_TAG} cho các service: ${builtServices.join(', ')}"

                            // Mapping tên service (lowercase, liền) → YAML key trong values.yaml
                            def serviceToYamlKey = [
                                'adservice'             : 'adService',
                                'cartservice'           : 'cartService',
                                'checkoutservice'       : 'checkoutService',
                                'currencyservice'       : 'currencyService',
                                'emailservice'          : 'emailService',
                                'frontend'              : 'frontend',
                                'productcatalogservice': 'productCatalogService',
                                'recommendationservice': 'recommendationService',
                                'shippingservice'      : 'shippingService',
                            ]

                            // Chuẩn hóa cú pháp yq v4 (bỏ chữ 'e' thừa để tránh xung đột phiên bản mới)
                            def yqUpdateCmds = builtServices.collect { svc ->
                                def yamlKey = serviceToYamlKey[svc]
                                if (yamlKey) {
                                    return "yq -i '.${yamlKey}.tag = \"${IMAGE_TAG}\"' helm-chart/microservices/values.yaml"
                                } else {
                                    return "echo '>>> CẢNH BÁO: Không tìm thấy YAML key cho service \"${svc}\", bỏ qua.'"
                                }
                            }.join('\n                                ')

                            def yqVerifyCmds = builtServices.collect { svc ->
                                def yamlKey = serviceToYamlKey[svc]
                                yamlKey
                                    ? "echo \"  ${svc}: \$(yq '.${yamlKey}.tag' helm-chart/microservices/values.yaml)\""
                                    : ""
                            }.findAll { it }.join('\n                                ')

                            def servicesList = builtServices.join(', ')

                            sh """
                                # ── 1. Cài đặt git và openssh-client cho Alpine ──────────────────
                                echo '>>> Đang chuẩn bị môi trường hệ thống (Cài git & openssh)...'
                                apk add --no-cache git openssh-client

                                # ── 2. FIX LỖI 128: Ép vào đúng Workspace và tắt cơ chế chặn quyền của Git ──
                                cd "${WORKSPACE}"
                                git config --global --add safe.directory '*'

                                # ── 3. Cài yq nếu chưa có ───────────────────────────────────────────
                                if ! which yq > /dev/null 2>&1; then
                                    echo '>>> Cài đặt yq...'
                                    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
                                    chmod +x /usr/local/bin/yq
                                fi

                                # ── 4. Cấu hình SSH từ key file được Jenkins inject ──────────────────
                                mkdir -p ~/.ssh
                                cp "\${SSH_KEY_FILE}" ~/.ssh/id_rsa
                                chmod 600 ~/.ssh/id_rsa

                                # Thêm github.com vào known_hosts để không bị treo hỏi Yes/No
                                ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null

                                # Ép git dùng đúng key file này cho mọi lệnh SSH
                                export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no"

                                # ── 5. Cấu hình git identity (Đã thêm cờ --global) ──────────────────
                                git config --global user.name  "${GIT_USER_NAME}"
                                git config --global user.email "${GIT_USER_EMAIL}"

                                # ── 6. Đảm bảo remote dùng SSH URL ──────────────────────────────────
                                CURRENT_REMOTE=\$(git remote get-url origin)
                                SSH_REMOTE=\$(echo "\${CURRENT_REMOTE}" \\
                                    | sed 's|https://github.com/|git@github.com:|' \\
                                    | sed 's|http://github.com/|git@github.com:|')
                                echo ">>> Remote URL (SSH): \${SSH_REMOTE}"

                                # ── 7. Cập nhật tag từng service đã build trong values.yaml ─────────
                                ${yqUpdateCmds}

                                echo '>>> Tags sau khi cập nhật:'
                                ${yqVerifyCmds}

                                # ── 8. Stage & commit ───────────────────────────────────────────────
                                git add helm-chart/microservices/values.yaml

                                if git diff --cached --quiet; then
                                    echo '>>> values.yaml không có thay đổi (tất cả tag đã trùng khớp), bỏ qua commit.'
                                else
                                    git commit -m "ci: update image tag to ${IMAGE_TAG} for [${servicesList}] [skip ci]"

                                    # Push qua SSH URL sử dụng định danh chính xác của Branch
                                    git push "\${SSH_REMOTE}" HEAD:${env.GIT_BRANCH_NAME}

                                    echo '>>> [GitOps] Đã push values.yaml lên Git thành công.'
                                    echo '>>> ArgoCD sẽ tự động phát hiện thay đổi và tiến hành sync.'
                                fi

                                # ── 9. Dọn dẹp an toàn ─────────────────────────────────────────────
                                rm -f ~/.ssh/id_rsa
                            """
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // Post Actions: Thông báo kết quả pipeline
    // =========================================================================
    post {
        success {
            echo """
            ╔══════════════════════════════════════════╗
            ║   PIPELINE THÀNH CÔNG!                   ║
            ║   Branch  : ${env.GIT_BRANCH_NAME}
            ║   Tag     : ${env.IMAGE_TAG}
            ║   Harbor  : ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/*:${env.IMAGE_TAG}
            ╚══════════════════════════════════════════╝
            """
        }
        failure {
            echo """
            ╔══════════════════════════════════════════╗
            ║   PIPELINE THẤT BẠI!                     ║
            ║   Branch  : ${env.GIT_BRANCH_NAME}
            ║   Tag     : ${env.IMAGE_TAG}
            ║   Kiểm tra log để biết stage bị lỗi.     ║
            ╚══════════════════════════════════════════╝
            """
        }
        always {
            // Dọn dẹp docker config.json chứa credentials sau khi pipeline hoàn tất
            container('tools') {
                sh 'rm -f /kaniko/.docker/config.json || true'
            }
        }
    }
}
