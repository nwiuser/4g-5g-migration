pipeline {
    agent any

    stages {
        stage('Deploy') {
            steps {
                echo 'Acceder au projet 4G'
                cd '4g'

                echo "Deploying containers with docker-compose (in 4G)"
                sh './start.sh'

                echo "Install taceroute and speed test into your srsUE container use:"
                sh './setup--cli.sh'

                echo "Configure internet access via corenetwrok use :"
                sh "./setup-internet-access.sh"
            }
        }
    }
}
