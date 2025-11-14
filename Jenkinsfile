pipeline {
    agent any

    options {
        timestamps()
    }

    environment {
        COMPOSE_DIR = '4G'
    }

    stages {
        stage('Diagnostics') {
            steps {
                script {
                    echo '=== Diagnostics: Jenkins node, workspace and tool versions ==='
                    echo "Node: ${env.NODE_NAME ?: 'unknown'}"
                    echo "Workspace: ${env.WORKSPACE ?: 'unknown'}"
                    echo "Build: ${env.BUILD_TAG ?: 'unknown'}"

                    if (isUnix()) {
                        sh '''
                        echo '--- uname -a ---'
                        uname -a || true
                        echo '--- whoami ---'
                        whoami || true
                        echo '--- ls -la workspace ---'
                        ls -la || true
                        echo '--- docker version ---'
                        docker --version || true
                        echo '--- docker-compose version ---'
                        docker-compose --version || true
                        echo '--- env (filtered) ---'
                        env | grep -E 'JENKINS|BUILD|WORKSPACE|NODE' || true
                        '''
                    } else {
                        bat '''
                        echo --- systeminfo ---
                        systeminfo || echo systeminfo unavailable
                        echo --- whoami ---
                        whoami || echo whoami unavailable
                        echo --- dir workspace ---
                        dir || echo dir unavailable
                        echo --- docker version ---
                        docker --version || echo docker unavailable
                        echo --- docker-compose version ---
                        docker-compose --version || echo docker-compose unavailable
                        '''
                    }
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout([$class: 'GitSCM', branches: [[name: '*/main']], userRemoteConfigs: [[url: 'https://github.com/nwiuser/4g-5g-migration', credentialsId: 'github-token']]])
                echo "Checked out repository"
            }
        }

        stage('Deploy') {
            steps {
                dir(env.COMPOSE_DIR) {
                    echo "Deploying containers with docker-compose (in ${env.COMPOSE_DIR})"
                    sh './start.sh'

                    echo "Install taceroute and speed test into your srsUE container"
                    sh './setup-cli.sh'

                    echo "Configure internet access via corenetwrok"
                    sh './setup-internet-access.sh'
                }
            }
        }
    }

    post {
        always {
            dir(env.COMPOSE_DIR) {
                echo 'Cleaning up: stopping and removing containers (docker-compose down)'
                sh 'docker-compose down --volumes --remove-orphans || true'
            }
        }
    }
}
