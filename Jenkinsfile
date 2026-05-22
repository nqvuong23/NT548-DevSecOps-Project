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
  # Shared emptyDir volume for nested dockerd socket
  - name: docker-run
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
    volumeMounts:
    - name: docker-run
      mountPath: /var/run

  # Container Docker để Build & Push Image lên Harbor (Task 2.4)
  - name: docker
    image: docker:24.0.7-dind
    command: [sleep]
    args: [infinity]
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-run
      mountPath: /var/run

  # Container kubectl + yq + argocd-cli để Update Helm & Trigger ArgoCD (Task 2.4)
  - name: tools
    image: alpine/k8s:1.28.3
    command: [sleep]
    args: [infinity]
    env:
    - name: HOME
      value: /root
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
                timeout(time: 10, unit: 'MINUTES') {
                    script {
                        echo ">>> Đang chờ kết quả Quality Gate từ SonarQube Webhook..."
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            error "Pipeline bị hủy vì không vượt qua được SonarQube Quality Gate! Trạng thái: ${qg.status}"
                        }
                        echo ">>> Quality Gate PASSED!"
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
        // STAGE 7: Build Docker Image - Task 2.4 [MỚI]
        // Build tất cả microservice có Dockerfile thay đổi
        // =====================================================================
        stage('Build Docker Images') {
            steps {
                container('docker') {
                    script {
                        // Khởi động dockerd (Docker-in-Docker) cục bộ với --insecure-registry
                        sh """
                            mkdir -p /etc/docker
                            echo '{"insecure-registries": ["${HARBOR_REGISTRY}", "${HARBOR_REGISTRY}:443"]}' > /etc/docker/daemon.json
                            if ! docker info >/dev/null 2>&1 || ! docker info | grep -q "${HARBOR_REGISTRY}"; then
                                echo ">>> Khởi động lại hoặc chạy mới dockerd với insecure-registry..."
                                pkill dockerd || true
                                pkill containerd || true
                                sleep 2
                                dockerd >/tmp/dockerd.log 2>&1 &
                                
                                # Chờ dockerd sẵn sàng
                                for i in {1..30}; do
                                    docker info >/dev/null 2>&1 && break
                                    echo "Chờ dockerd khởi động..."
                                    sleep 2
                                done
                            fi
                        """

                        echo ">>> Đang build Docker Image với tag: ${IMAGE_TAG}..."

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
                                def imageFull = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${svc}:${IMAGE_TAG}"
                                def imageLatest = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${svc}:latest"

                                if (fileExists(dockerfilePath)) {
                                    echo ">>> Building: ${imageFull}"
                                    sh """
                                        docker build \\
                                          -t ${imageFull} \\
                                          -t ${imageLatest} \\
                                          -f ${dockerfilePath} \\
                                          ./app_src/${svc}
                                    """
                                } else {
                                    echo ">>> Bỏ qua ${svc}: không tìm thấy Dockerfile tại ${dockerfilePath}"
                                }
                            } else {
                                echo ">>> Bỏ qua ${svc}: không có thay đổi"
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // STAGE 8: Image Scan - Trivy - Task 2.4 [CẬP NHẬT]
        // Quét image vừa build thay vì alpine:3.18
        // =====================================================================
        stage('Image Scan - Trivy') {
            steps {
                container('trivy') {
                    script {
                        echo ">>> Đang bắt đầu quét Docker Image bằng Trivy..."

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
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-image-*-report.json', allowEmptyArchive: true
                }
            }
        }

        // =====================================================================
        // STAGE 9: Push to Harbor - Task 2.4 [MỚI]
        // Lấy Harbor robot account credential từ Vault thay vì Jenkins credential
        // Lưu ý: username chứa ký tự "$" nên phải dùng double-quote khi expand
        //        biến shell để tránh shell tái diễn giải giá trị.
        // =====================================================================
        stage('Push to Harbor') {
            steps {
                container('docker') {
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
                            // Khởi động/kiểm tra dockerd cục bộ trước khi login/push
                            sh """
                                mkdir -p /etc/docker
                                echo '{"insecure-registries": ["${HARBOR_REGISTRY}", "${HARBOR_REGISTRY}:443"]}' > /etc/docker/daemon.json
                                if ! docker info >/dev/null 2>&1 || ! docker info | grep -q "${HARBOR_REGISTRY}"; then
                                    echo ">>> Khởi động lại hoặc chạy mới dockerd với insecure-registry..."
                                    pkill dockerd || true
                                    pkill containerd || true
                                    sleep 2
                                    dockerd >/tmp/dockerd.log 2>&1 &
                                    
                                    # Chờ dockerd sẵn sàng
                                    for i in {1..30}; do
                                        docker info >/dev/null 2>&1 && break
                                        echo "Chờ dockerd khởi động..."
                                        sleep 2
                                    done
                                fi
                            """

                            echo ">>> Đang push Docker Image lên Harbor Registry: ${HARBOR_REGISTRY}..."

                            // Login vào Harbor
                            // Dùng double-quote quanh "$HARBOR_USER" để shell expand biến một lần,
                            // tránh tái diễn giải ký tự "$" bên trong giá trị username (vd: robot$project+jenkins)
                            sh '''
                                echo "$HARBOR_PASS" | docker login "$HARBOR_REGISTRY" -u "$HARBOR_USER" --password-stdin
                            '''

                            def services = [
                                'adservice', 'cartservice', 'checkoutservice',
                                'currencyservice', 'emailservice', 'frontend',
                                'paymentservice', 'productcatalogservice',
                                'recommendationservice', 'shippingservice'
                            ]

                            services.each { svc ->
                                if (env.CHANGED_FILES.contains("app_src/${svc}") || env.CHANGED_FILES.isEmpty()) {
                                    if (fileExists("app_src/${svc}/Dockerfile")) {
                                        def imageFull   = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${svc}:${IMAGE_TAG}"
                                        def imageLatest = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${svc}:latest"
                                        echo ">>> Pushing: ${imageFull}"
                                        sh """
                                            docker push ${imageFull}
                                            docker push ${imageLatest}
                                        """
                                    }
                                } else {
                                    echo ">>> Bỏ qua push cho ${svc}: không có thay đổi"
                                }
                            }

                            // Logout để bảo mật
                            sh 'docker logout $HARBOR_REGISTRY'
                        }

                        echo ">>> Push thành công! Image tag: ${IMAGE_TAG}"
                    }
                }
            }
        }

        // =====================================================================
        // STAGE 10: Trigger ArgoCD Sync - Task 2.4 [MỚI]
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
                                argocd app set ${ARGOCD_APP_NAME} \
                                  --helm-set images.tag=${IMAGE_TAG} \
                                  --grpc-web \
                                  --plaintext
                            """

                            // Trigger sync
                            sh """
                                argocd app sync ${ARGOCD_APP_NAME} \
                                  --grpc-web \
                                  --plaintext \
                                  --timeout 300
                            """

                            // Chờ ArgoCD sync hoàn thành và healthy
                            sh """
                                argocd app wait ${ARGOCD_APP_NAME} \
                                  --health \
                                  --grpc-web \
                                  --plaintext \
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
            // Dọn dẹp Docker images cũ để tiết kiệm disk
            container('docker') {
                sh 'docker image prune -f --filter "until=24h" || true'
            }
        }
    }
}
