pipeline {
	agent none
	stages {
		stage("Setup Script Deployment") {
			parallel {
				stage("Debian 10") {
					stages {
						stage("Script On Server") {
							agent {
								label "debian10"
							}
							steps {
								script {
									if (env.CHANGE_ID) {
										pullRequest.createStatus(status: "pending", context: "setup-scripts/debian10", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL")
									}
									debian_instance_id = getInstanceId()
								}
								callScriptOnServer()
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/debian10", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL")
											sendErrorEmail("debian_10/${env.STAGE_NAME}")
										}
									}
								}
								aborted {
									terminateInstance("${debian_instance_id}", "us-east-1")
								}
								cleanup {
									terminateInstance("${debian_instance_id}", "us-east-1")
								}
							}
						}
						stage("Through Web URL") {
							agent {
								label "debian10"
							}
							steps {
								script {
									if (env.CHANGE_ID) {
										pullRequest.createStatus(status: "pending", context: "setup-scripts/debian10", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL")
									}
									debian_instance_id = getInstanceId()
								}
								callScriptFromURL()
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "success", context: "setup-scripts/debian10", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL")
										}
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/debian10", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL")
											sendErrorEmail("debian_10/${env.STAGE_NAME}")
										}
									}
								}
								aborted {
									terminateInstance("${debian_instance_id}", "us-east-1")
								}
								cleanup {
									terminateInstance("${debian_instance_id}", "us-east-1")
								}
							}
						}
					}
				}
				stage("Ubuntu 18.04") {
					stages {
						stage("Script On Server") {
							agent {
								label "ubuntu18"
							}
							steps {
								script {
									if (env.CHANGE_ID) {
										pullRequest.createStatus(status: "pending", context: "setup-scripts/ubuntu18", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL")
									}
									u18_instance_id = getInstanceId()
								}
								callScriptOnServer()
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/ubuntu18", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL")
											sendErrorEmail("ubuntu_1804/${env.STAGE_NAME}")
										}
									}
								}
								aborted {
									terminateInstance("${u18_instance_id}", "us-east-1")
								}
								cleanup {
									terminateInstance("${u18_instance_id}", "us-east-1")
								}
							}
						}
						stage("Through Web URL") {
							agent {
								label "ubuntu18"
							}
							steps {
								script {
									if (env.CHANGE_ID) {
										pullRequest.createStatus(status: "pending", context: "setup-scripts/ubuntu18", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL")
									}
									u18_instance_id = getInstanceId()
								}
								callScriptFromURL()
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "success", context: "setup-scripts/ubuntu18", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL")
										}
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/ubuntu18", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL")
											sendErrorEmail("ubuntu_1804/${env.STAGE_NAME}")
										}
									}
								}
								aborted {
									terminateInstance("${u18_instance_id}", "us-east-1")
								}
								cleanup {
									terminateInstance("${u18_instance_id}", "us-east-1")
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
								script {
									if (env.CHANGE_ID) {
										pullRequest.createStatus(status: "pending", context: "setup-scripts/ubuntu20", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL")
									}
									u20_instance_id = getInstanceId()
								}
								callScriptOnServer()
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/ubuntu20", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL")
											sendErrorEmail("ubuntu_2004/${env.STAGE_NAME}")
										}
									}
								}
								aborted {
									terminateInstance("${u20_instance_id}", "us-east-1")
								}
								cleanup {
									terminateInstance("${u20_instance_id}", "us-east-1")
								}
							}
						}
						stage('Through Web URL') {
							agent {
								label 'ubuntu20'
							}
							steps {
								script {
									if (env.CHANGE_ID) {
										pullRequest.createStatus(status: "pending", context: "setup-scripts/ubuntu20", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL")
									}
									u20_instance_id = getInstanceId()
								}
								callScriptFromURL()
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "success", context: "setup-scripts/ubuntu20", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL")
										}
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/ubuntu20", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL")
											sendErrorEmail("ubuntu_2004/${env.STAGE_NAME}")
										}
									}
								}
								aborted {
									terminateInstance("${u20_instance_id}", "us-east-1")
								}
								cleanup {
									terminateInstance("${u20_instance_id}", "us-east-1")
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
								script {
									if (env.CHANGE_ID) {
										pullRequest.createStatus(status: "pending", context: "setup-scripts/sles12", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL")
									}
									sles12_instance_id = getInstanceId()
								}
								suseRegisterCloudGuest()
								callScriptOnServer()
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/sles12", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL")
											sendErrorEmail("sles_12/${env.STAGE_NAME}")
										}
									}
								}
								aborted {
									terminateInstance("${sles12_instance_id}", "us-east-1")
								}
								cleanup {
									terminateInstance("${sles12_instance_id}", "us-east-1")
								}
							}
						}
						stage('Through Web URL') {
							agent {
								label 'sles12'
							}
							steps {
								script {
									if (env.CHANGE_ID) {
										pullRequest.createStatus(status: "pending", context: "setup-scripts/sles12", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL")
									}
									sles12_instance_id = getInstanceId()
								}
								suseRegisterCloudGuest()
								callScriptFromURL()
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "success", context: "setup-scripts/sles12", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL")
										}
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/sles12", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL")
											sendErrorEmail("sles_12/${env.STAGE_NAME}")
										}
									}
								}
								aborted {
									terminateInstance("${sles12_instance_id}", "us-east-1")
								}
								cleanup {
									terminateInstance("${sles12_instance_id}", "us-east-1")
								}
							}
						}
					}
				}
				stage('SLES 15') {
					stages {
						stage('Script On Server') {
							agent {
								label 'sles15'
							}
							steps {
								script {
									if (env.CHANGE_ID) {
										pullRequest.createStatus(status: "pending", context: "setup-scripts/sles15", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL")
									}
									sles15_instance_id = getInstanceId()
								}
								callScriptOnServer()
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/sles15", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL")
											sendErrorEmail("sles_15/${env.STAGE_NAME}")
										}
									}
								}
								aborted {
									terminateInstance("${sles15_instance_id}", "us-east-1")
								}
								cleanup {
									terminateInstance("${sles15_instance_id}", "us-east-1")
								}
							}
						}
						stage('Through Web URL') {
							agent {
								label 'sles15'
							}
							steps {
								script {
									if (env.CHANGE_ID) {
										pullRequest.createStatus(status: "pending", context: "setup-scripts/sles15", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL")
									}
									sles15_instance_id = getInstanceId()
								}
								callScriptFromURL()
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "success", context: "setup-scripts/sles15", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL")
										}
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/sles15", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL")
											sendErrorEmail("sles_15/${env.STAGE_NAME}")
										}
									}
								}
								aborted {
									terminateInstance("${sles15_instance_id}", "us-east-1")
								}
								cleanup {
									terminateInstance("${sles15_instance_id}", "us-east-1")
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
								script {
									if (env.CHANGE_ID) {
										pullRequest.createStatus(status: "pending", context: "setup-scripts/rhel8", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL")
									}
									rhel_instance_id = getInstanceId()
								}
								callScriptOnServer()
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/rhel8", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL")
											sendErrorEmail("rhel_8/${env.STAGE_NAME}")
										}
									}
								}
								aborted {
									terminateInstance("${rhel_instance_id}", "us-east-1")
								}
								cleanup {
									terminateInstance("${rhel_instance_id}", "us-east-1")
								}
							}
						}
						stage('Through Web URL') {
							agent {
								label 'rhel8'
							}
							steps {
								script {
									if (env.CHANGE_ID) {
										pullRequest.createStatus(status: "pending", context: "setup-scripts/rhel8", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL")
									}
									rhel_instance_id = getInstanceId()
								}
								callScriptFromURL()
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "success", context: "setup-scripts/rhel8", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL")
										}
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/rhel8", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL")
											sendErrorEmail("rhel_8/${env.STAGE_NAME}")
										}
									}
								}
								aborted {
									terminateInstance("${rhel_instance_id}", "us-east-1")
								}
								cleanup {
									terminateInstance("${rhel_instance_id}", "us-east-1")
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
								script {
									if (env.CHANGE_ID) {
										pullRequest.createStatus(status: "pending", context: "setup-scripts/centos7", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL")
									}
									centos_instance_id = getInstanceId()
								}
								callScriptOnServer()
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/centos7", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL")
											sendErrorEmail("centos_7/${env.STAGE_NAME}")
										}
									}
								}
								aborted {
									terminateInstance("${centos_instance_id}", "us-east-1")
								}
								cleanup {
									terminateInstance("${centos_instance_id}", "us-east-1")
								}
							}
						}
						stage('Through Web URL') {
							agent {
								label 'centos7'
							}
							steps {
								script {
									if (env.CHANGE_ID) {
										pullRequest.createStatus(status: "pending", context: "setup-scripts/centos7", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL")
									}
									centos_instance_id = getInstanceId()
								}
								callScriptFromURL()
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "success", context: "setup-scripts/centos7", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL")
										}
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/centos7", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL")
											sendErrorEmail("centos_7/${env.STAGE_NAME}")
										}
									}
								}
								aborted {
									terminateInstance("${centos_instance_id}", "us-east-1")
								}
								cleanup {
									terminateInstance("${centos_instance_id}", "us-east-1")
								}
							}
						}
					}
				}
			}
			post {
				success {
					sendSuccessEmail()
				}
			}
		}
	}
}

void callScriptOnServer() {
	sh "sudo ./simplerisk-setup.sh -n -d"
	validateStatusCode()
}

def getInstanceId() {
	return sh(script: 'echo $(TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` && curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)', returnStdout: true).trim()
}

void terminateInstance(String instanceId, String region, Integer number=60) {
	node("terminator") {
		sh "aws ec2 terminate-instances --instance-ids $instanceId --region $region"
		sh "sleep $number"
	}
}

void callScriptFromURL() {
	sh "curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/${(env.CHANGE_ID != null ? pullRequest.head : env.BRANCH_NAME)}/simplerisk-setup.sh | sudo bash -s -- -n -d"
	validateStatusCode()
}

void validateStatusCode(String urlToCheck="https://localhost") {
	sh "[ \"\$(curl -s -o /dev/null -w '%{http_code}' -k $urlToCheck)\" = \"200\" ] && exit 0 || exit 1"
}

void sendEmail(String message) {
        mail from: 'jenkins@simplerisk.com', to: "$env.GIT_AUTHOR_EMAIL", bcc: '',  cc: 'pedro@simplerisk.com', replyTo: '',
             subject: """${env.JOB_NAME} (Branch ${env.BRANCH_NAME}) - Build # ${env.BUILD_NUMBER} - ${currentBuild.currentResult}""",
             body: "$message"
}

void sendErrorEmail(String stage) {
        sendEmail("""Job failed at stage \"${stage}\". Check console output at ${env.BUILD_URL} to view the results (The Blue Ocean option will provide the detailed execution flow).""")
}

void sendSuccessEmail() {
        sendEmail("""Check console output at ${env.BUILD_URL} to view the results (The Blue Ocean option will provide the detailed execution flow).""")
}

void suseRegisterCloudGuest() {
	sh """
		sudo rm /etc/SUSEConnect
		sudo rm -f /etc/zypp/{repos,services,credentials}.d/*
		sudo rm -f /usr/lib/zypp/plugins/services/*
		sudo sed -i '/^# Added by SMT reg/,+1d' /etc/hosts
		sudo /usr/sbin/registercloudguest --force-new
	"""
}

void ubuntuReconfiguredpkg() {
	sh '''
		sudo rm -f /var/lib/dpkg/lock
		sudo rm -f /var/lib/dpkg/lock-frontend
		sudo rm -f /var/apt/lists/lock
		sudo rm -f /var/cache/apt/archives/lock
		sudo dpkg --configure -a
	'''
}
