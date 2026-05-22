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
                            path: 'devsecops_nhom10/sonarqube',
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
                            path: 'devsecops_nhom10/sonarqube',
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
        // Lưu ý: Stage 9 (Push) đã được hợp nhất vào đây vì Kaniko build
        //        và push cùng lúc qua flag --destination.
        // =====================================================================
        stage('Build & Push Images via Kaniko') {
            steps {
                // Bước 1: Lấy credentials từ Vault và ghi docker config.json
                // vào shared volume để Kaniko có thể đọc khi xác thực với Harbor.
                // Thực hiện trong container 'tools' (có shell đầy đủ).
                container('tools') {
                    withVault(vaultSecrets: [
                        [
                            path: 'devsecops_nhom10/harbor',
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
                            'paymentservice',
                            'productcatalogservice',
                            'recommendationservice',
                            'shippingservice'
                        ]

                        services.each { svc ->
                            def dockerfilePath = "app_src/${svc}/Dockerfile"

                            // Build nếu service này có thay đổi HOẶC lần đầu chạy
                            if (env.CHANGED_FILES.contains("app_src/${svc}") || env.CHANGED_FILES.isEmpty()) {
                                if (fileExists(dockerfilePath)) {
                                    def imageFull   = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${svc}:${IMAGE_TAG}"
                                    def imageLatest = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${svc}:latest"

                                    echo ">>> Building & Pushing: ${imageFull}"

                                    // Kaniko executor:
                                    //   --context       : thư mục build context
                                    //   --dockerfile    : đường dẫn Dockerfile
                                    //   --destination   : image đích (build + push cùng lúc)
                                    //   --skip-tls-verify: bỏ qua TLS nếu Harbor dùng self-signed cert
                                    //                      (xóa dòng này nếu Harbor có cert hợp lệ)
                                    //   --cache         : bật layer cache để tăng tốc build lần sau
                                    //   --cache-repo    : nơi lưu cache layers trên Harbor
                                    sh """
                                        /kaniko/executor \\
                                          --context      \$(pwd)/app_src/${svc} \\
                                          --dockerfile   \$(pwd)/${dockerfilePath} \\
                                          --destination  ${imageFull} \\
                                          --destination  ${imageLatest} \\
                                          --cache=true \\
                                          --cache-repo   ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/cache
                                    """
                                    echo ">>> Kaniko đã build và push thành công: ${imageFull}"
                                } else {
                                    echo ">>> Bỏ qua ${svc}: không tìm thấy Dockerfile tại ${dockerfilePath}"
                                }
                            } else {
                                echo ">>> Bỏ qua ${svc}: không có thay đổi"
                            }
                        }

                        echo ">>> Build & Push hoàn tất! Image tag: ${IMAGE_TAG}"
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
                            path: 'devsecops_nhom10/harbor',
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
        // STAGE 9: Trigger ArgoCD Sync - Task 2.4
        // Lấy ArgoCD token từ Vault thay vì Jenkins credential
        // =====================================================================
        stage('Trigger ArgoCD Sync') {
            steps {
                container('tools') {
                    withVault(vaultSecrets: [
                        [
                            path: 'devsecops_nhom10/argocd',
                            engineVersion: 2,
                            secretValues: [
                                [envVar: 'ARGOCD_AUTH_TOKEN', vaultKey: 'token']
                            ]
                        ]
                    ]) {
                        script {
                            echo ">>> Đang cấu hình và trigger ArgoCD sync cho app: ${ARGOCD_APP_NAME}..."

                            // Cài argocd CLI nếu chưa có
                            sh """
                                which argocd || (
                                    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 &&
                                    chmod +x /usr/local/bin/argocd
                                )
                            """

                            // Sử dụng tính năng Parameter Overrides của ArgoCD để set tag image mới động
                            // mà không cần phải commit & push thay đổi lên Git, giữ sạch lịch sử commit GitHub!
                            sh """
                                argocd app set ${ARGOCD_APP_NAME} \\
                                  --helm-set images.tag=${IMAGE_TAG} \\
                                  --grpc-web \\
                                  --plaintext
                            """

                            // Trigger sync
                            sh """
                                argocd app sync ${ARGOCD_APP_NAME} \\
                                  --grpc-web \\
                                  --plaintext \\
                                  --timeout 300
                            """

                            // Chờ ArgoCD sync hoàn thành và healthy
                            sh """
                                argocd app wait ${ARGOCD_APP_NAME} \\
                                  --health \\
                                  --grpc-web \\
                                  --plaintext \\
                                  --timeout 300
                            """

                            echo ">>> ArgoCD sync thành công! App ${ARGOCD_APP_NAME} đang healthy với tag: ${IMAGE_TAG}."
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
