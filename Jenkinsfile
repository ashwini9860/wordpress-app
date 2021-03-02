pipeline {
  agent any
  tools {
        dockerTool "docker"
    }
  options {
        buildDiscarder logRotator(
                    daysToKeepStr: '15',
                    numToKeepStr: '5'
            )
    }

  environment {
    registry = "auchoudhari/wordpress-test"
    registryCredential = 'dockerhub'
    dockerImage = ''
  }
  stages {
    stage('Clone Git repo') {
      steps {
        git 'https://github.com/ashwini9860/wordpress-app.git'
      }
    }
    stage('Create Image') {
      steps{
        script {
          dockerImage = docker.build registry + ":$BUILD_NUMBER"
        }
      }
    }
    stage('Deploy Image') {
      steps{
        script {
          docker.withRegistry( '', registryCredential ) {
            dockerImage.push()
          }
        }
      }
    }
    stage('Remove Image') {
      steps{
        sh "docker rmi $registry:$BUILD_NUMBER"
      }
    }
  }
}
