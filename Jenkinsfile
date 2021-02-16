pipeline {
	agent none
	stages {
		stage('Setup Script Deployment') {
			parallel {
				stage('Ubuntu 18.04') {
					stages {
						stage('Script On Server') {
							agent {
								label 'ubuntu18'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/ubuntu18", message: "Installing SimpleRisk through script on server...", state: "PENDING"
								callScriptOnServer()
								script {
									u18_instance_id = getInstanceId() 
								}
							}
							post {
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/ubuntu18", message: "Couldn't install SimpleRisk through script on server.", state: "FAILURE"
								}
							}
						}
						stage('Cooldown') {
							agent {
								label 'jenkins'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/ubuntu18", message: "Destroying server...", state: "PENDING"
								terminateInstance("${u18_instance_id}", "us-east-1")
								sleep time: 30, unit: "SECONDS"
							}
							post {
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/ubuntu18", message: "Couldn't destroy server.", state: "FAILURE"
								}
							}
						}
						stage('Through Web URL') {
							agent {
								label 'ubuntu18'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/ubuntu18", message: "Installing SimpleRisk through URL...", state: "PENDING"
								callScriptFromURL()
							}
							post {
								success {
									setGitHubPullRequestStatus context: "setup-scripts/ubuntu18", message: "SimpleRisk installed successfully.", state: "SUCCESS"
								}
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/ubuntu18", message: "Couldn't install SimpleRisk through URL.", state: "FAILURE"
								}
							}
						}
					}
				}
				stage('Ubuntu 20.04') {
					stages {
						stage('Script On Server') {
							agent {
								label 'ubuntu20'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/ubuntu20", message: "Installing SimpleRisk through script on server...", state: "PENDING"
								callScriptOnServer()
								script {
									u20_instance_id = getInstanceId() 
								}
							}
							post {
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/ubuntu20", message: "Couldn't install SimpleRisk through script on server.", state: "FAILURE"
								}
							}
						}
						stage('Cooldown') {
							agent {
								label 'jenkins'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/ubuntu20", message: "Destroying server...", state: "PENDING"
								terminateInstance("${u20_instance_id}", "us-east-1")
								sleep time: 30, unit: "SECONDS"
							}
							post {
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/ubuntu20", message: "Couldn't destroy server.", state: "FAILURE"
								}
							}
						}
						stage('Through Web URL') {
							agent {
								label 'ubuntu20'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/ubuntu20", message: "Installing SimpleRisk through URL...", state: "PENDING"
								callScriptFromURL()
							}
							post {
								success {
									setGitHubPullRequestStatus context: "setup-scripts/ubuntu20", message: "SimpleRisk installed successfully.", state: "SUCCESS"
								}
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/ubuntu20", message: "Couldn't install SimpleRisk through URL.", state: "FAILURE"
								}
							}
						}
					}
				}
				stage('SLES 12') {
					stages {
						stage('Script On Server') {
							agent {
								label 'sles12'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/sles12", message: "Installing SimpleRisk through script on server...", state: "PENDING"
								callScriptOnServer()
								script {
									sles_instance_id = getInstanceId() 
								}
							}
							post {
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/sles12", message: "Couldn't install SimpleRisk through script on server.", state: "FAILURE"
								}
							}
						}
						stage('Cooldown') {
							agent {
								label 'jenkins'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/sles12", message: "Destroying server...", state: "PENDING"
								terminateInstance("${sles_instance_id}", "us-east-1")
								sleep time: 30, unit: "SECONDS"
							}
							post {
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/sles12", message: "Couldn't destroy server.", state: "FAILURE"
								}
							}
						}
						stage('Through Web URL') {
							agent {
								label 'sles12'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/sles12", message: "Installing SimpleRisk through URL...", state: "PENDING"
								callScriptFromURL()
							}
							post {
								success {
									setGitHubPullRequestStatus context: "setup-scripts/sles12", message: "SimpleRisk installed successfully.", state: "SUCCESS"
								}
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/sles12", message: "Couldn't install SimpleRisk through URL.", state: "FAILURE"
								}
							}
						}
					}
				}
				stage('RHEL 8') {
					stages {
						stage('Script On Server') {
							agent {
								label 'rhel8'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/rhel8", message: "Installing SimpleRisk through script on server...", state: "PENDING"
								callScriptOnServer()
								script {
									rhel_instance_id = getInstanceId()
								}
							}
							post {
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/rhel8", message: "Couldn't install SimpleRisk through script on server.", state: "FAILURE"
								}
							}
						}
						stage('Cooldown') {
							agent {
								label 'jenkins'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/rhel8", message: "Destroying server...", state: "PENDING"
								terminateInstance("${rhel_instance_id}", "us-east-1")
								sleep time: 30, unit: "SECONDS"
							}
							post {
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/rhel8", message: "Couldn't destroy server.", state: "FAILURE"
								}
							}
						}
						stage('Through Web URL') {
							agent {
								label 'rhel8'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/rhel8", message: "Installing SimpleRisk through URL...", state: "PENDING"
								callScriptFromURL()
							}
							post {
								success {
									setGitHubPullRequestStatus context: "setup-scripts/rhel8", message: "SimpleRisk installed successfully.", state: "SUCCESS"
								}
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/rhel8", message: "Couldn't install SimpleRisk through URL.", state: "FAILURE"
								}
							}
						}
					}
				}
				stage('CentOS 7') {
					stages {
						stage('Script On Server') {
							agent {
								label 'centos7'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/centos7", message: "Installing SimpleRisk through script on server...", state: "PENDING"
								callScriptOnServer()
								script {
									centos_instance_id = getInstanceId()
								}	
							}
							post {
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/centos7", message: "Couldn't install SimpleRisk through script on server.", state: "FAILURE"
								}
							}
						}
						stage('Cooldown') {
							agent {
								label 'jenkins'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/centos7", message: "Destroying server...", state: "PENDING"
								terminateInstance("${centos_instance_id}", "us-east-1")
								sleep time: 30, unit: "SECONDS"
							}
							post {
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/centos7", message: "Couldn't destroy server.", state: "FAILURE"
								}
							}
						}
						stage('Through Web URL') {
							agent {
								label 'centos7'
							}
							steps {
								setGitHubPullRequestStatus context: "setup-scripts/centos7", message: "Installing SimpleRisk through URL...", state: "PENDING"
								callScriptFromURL()
							}
							post {
								success {
									setGitHubPullRequestStatus context: "setup-scripts/centos7", message: "SimpleRisk installed successfully.", state: "SUCCESS"
								}
								failure {
									setGitHubPullRequestStatus context: "setup-scripts/centos7", message: "Couldn't install SimpleRisk through URL.", state: "FAILURE"
								}
							}
						}
					}
				}
			}
		}
	}
}

void callScriptOnServer() {
	sh '''
		sudo ./simplerisk-setup.sh -n
		[ "$(curl -s -o /dev/null -w '%{http_code}' -k https://localhost)" = "200" ] && exit 0 || exit 1
	'''
}

def getInstanceId() {
	return sh(script: 'echo $(TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` && curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)', returnStdout: true).trim()
}

void terminateInstance(String instanceId, String region) {
	sh "aws ec2 terminate-instances --instance-ids $instanceId --region $region"
}

void callScriptFromURL() {
	sh '''
		curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/${GITHUB_PR_HEAD_SHA}/simplerisk-setup.sh | sudo bash -s -- -n
		[ "$(curl -s -o /dev/null -w '%{http_code}' -k https://localhost)" = "200" ] && exit 0 || exit 1
	'''
}
