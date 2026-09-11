pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "yg7821/devopsexamapp:v4"
        SCANNER_HOME = tool 'sonar-scanner'
		AWS_CREDENTIALS_ID = 'aws-credentials'
		AWS_REGION = 'ap-south-1'
		EKS_CLUSTER_NAME = 'my-eks-cluster'
		ZAP_DIR = "${workspace}"
    }

    stages {

        stage('Git Checkout') {
            steps {
                echo "📦 Checking out source code..."
                git(
                    url: 'https://github.com/YogitaDevOps12/devopsexam.git',        
                    branch: 'main'
                )
            }
        }
       

        stage('File System Scan') {
            steps {
                echo "🔍 Running Trivy File System Scan..."
                sh "trivy fs --security-checks vuln,config --format table -o trivy-fs-report.html ."
            }
        }

        stage('SonarQube Analysis') {
            steps {
                echo "🧠 Running SonarQube Code Analysis..."
                withSonarQubeEnv('sonar') {
                    sh """
                    ${SCANNER_HOME}/bin/sonar-scanner \
                    -Dsonar.projectName=devops-exam-app \
                    -Dsonar.projectKey=devops-exam-app \
                    -Dsonar.sources=. \
                    -Dsonar.language=py \
                    -Dsonar.python.version=3 \
                    -Dsonar.host.url=http://localhost:9000
                    """
                }
            }
        }

        stage('Build and Push Docker Image') {
            steps {
                dir('quizapp') {
                    script {
                        echo "🐳 Building and pushing Docker image..."
                        
                        withDockerRegistry(credentialsId: 'docker') {
                            sh "docker build -t ${DOCKER_IMAGE} ."
                            sh "docker push ${DOCKER_IMAGE}"
                        }
                    }
                }
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh "trivy image --security-checks vuln,config --format table -o trivy-image-report.html ${DOCKER_IMAGE}"
            }
        }

        stage('Connect & Deploy to EKS') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding', 
                    credentialsId: "${AWS_CREDENTIALS_ID}"
                ]]) {
                    sh """
                        # Update kubeconfig to point to your EKS cluster
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}
                        
                        # Verify connection
                        kubectl get nodes
                        
                        # Deploy application
                        kubectl apply -f k8s/configmap.yaml
                        kubectl apply -f k8s/secret.yaml
                        kubectl apply -f k8s/pv.yaml
                        kubectl apply -f k8s/pvc.yaml
                        kubectl apply -f k8s/service.yaml
                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/statefulset.yaml
						
                    """
                }
            }
        }
		
        stage('Deploy Monitoring Stack') {
            steps {
               withCredentials([[
                   $class: 'AmazonWebServicesCredentialsBinding',
                   credentialsId: "${AWS_CREDENTIALS_ID}"
               ]]) {
                   sh """
                       aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}

                       helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
                       helm repo update

                       helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
                       --namespace devsecops --create-namespace

                       kubectl apply -f k8s/grafana-service.yaml
                  """
               }
           }
       }		
		

       stage('Get Load Balancer URL for the App') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: "${AWS_CREDENTIALS_ID}"
                ]]) {
                    script {
                        def lbHost = ''
                        // Retry a few times in case the ELB hostname isn't populated yet.
                        // Uses {range ...}{end} so an empty ingress array prints nothing
                        // instead of kubectl throwing an "array index out of bounds"
                        // error - and wraps the call in try/catch so a genuine failure
                        // on any single attempt doesn't kill the whole retry loop.
                        for (int i = 0; i < 15 && !lbHost; i++) {
                            try {
                                lbHost = sh(
                                    script: "kubectl get svc flask -o jsonpath='{range .status.loadBalancer.ingress[*]}{.hostname}{end}'",
                                    returnStdout: true
                                ).trim()
                            } catch (e) {
                                echo "kubectl call failed on attempt ${i + 1}: ${e.getMessage()}"
                            }
                            if (!lbHost) {
                                echo "Waiting for LoadBalancer hostname... (attempt ${i + 1}/15)"
                                sleep(10)
                            }
                        }
                        if (!lbHost) {
                            error("Could not retrieve LoadBalancer hostname for service 'flask' after 15 attempts")
                        }
                        env.TARGET_URL = "http://${lbHost}:5000"
                        echo "🎯 ZAP will scan: ${env.TARGET_URL}"
                    }
                }
            }
        }

        
 


        stage('Wait for App to be Reachable') {
            steps {
                echo "⏳ Waiting 35s for the ELB to register the new pod as a healthy target..."
                sleep(35)
            }
        }
                 
		stage('OWASP ZAP DAST Scan') {
            steps {
			     script {
			         withDockerRegistry(credentialsId: 'docker') {
                     sh  """
                        docker run --user root -v ${WORKSPACE}:/zap/wrk:rw zaproxy/zap-stable:latest \
                        zap-baseline.py -t ${env.TARGET_URL} -r zap_report.html || true
                         """
                    }
                }
            }
        }
    }
           

    post {
        success {
            echo '🎉 Deployment successful!'
            archiveArtifacts artifacts: 'trivy-fs-report.html', allowEmptyArchive: true
            archiveArtifacts artifacts: 'trivy-image-report.html', allowEmptyArchive: true
			archiveArtifacts artifacts: 'zap_report.html', fingerprint: true
        }

        always {
            archiveArtifacts artifacts: 'trivy-fs-report.html', allowEmptyArchive: true
            archiveArtifacts artifacts: 'trivy-image-report.html', allowEmptyArchive: true
			archiveArtifacts artifacts: 'zap_report.html', fingerprint: true
        }
    }
}
