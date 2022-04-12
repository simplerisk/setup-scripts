@Library('simplerisk@STABLE') _

pipeline {
	agent none
	stages {
		stage("Initializing Common Variables") {
			agent { label "terminator" }
			steps {
				script { committer_email = gitOps.getCommitterEmail() }
			}
			post {
				failure { 
					script { emailOps.sendErrorEmail("${env.STAGE_NAME}", "${committer_email}") }
				}
			}
		}
		stage("Setup Script Deployment") {
			parallel {
				stage("Debian 10") {
					stages {
						stage("Script On Server") {
							agent { label "debian10" }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/debian10", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL") }
									debian_instance_id = awsOps.getEC2Metadata("instance-id")
								}
								callScriptOnServer()
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/debian10", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("debian_10/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								aborted {
									script { awsOps.terminateInstance("${debian_instance_id}", "us-east-1") }
								}
								cleanup {
									script { awsOps.terminateInstance("${debian_instance_id}", "us-east-1") }
								}
							}
						}
						stage("Through Web URL") {
							agent { label "debian10" }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/debian10", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									debian_instance_id = awsOps.getEC2Metadata("instance-id")
								}
								callScriptFromURL()
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "success", context: "setup-scripts/debian10", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL") }
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/debian10", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("debian_10/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								aborted {
									script { awsOps.terminateInstance("${debian_instance_id}", "us-east-1") }
								}
								cleanup {
									script { awsOps.terminateInstance("${debian_instance_id}", "us-east-1") }
								}
							}
						}
					}
				}
				stage("Ubuntu 18.04") {
					stages {
						stage("Script On Server") {
							agent { label "ubuntu18" }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/ubuntu18", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL") }
									u18_instance_id = awsOps.getEC2Metadata("instance-id")
								}
								sh "sleep 2m"
								callScriptOnServer()
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/ubuntu18", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("ubuntu_1804/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								aborted {
									script { awsOps.terminateInstance("${u18_instance_id}", "us-east-1") }
								}
								cleanup {
									script { awsOps.terminateInstance("${u18_instance_id}", "us-east-1") }
								}
							}
						}
						stage("Through Web URL") {
							agent { label "ubuntu18" }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/ubuntu18", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									u18_instance_id = awsOps.getEC2Metadata("instance-id")
								}
								sh "sleep 2m"
								callScriptFromURL()
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "success", context: "setup-scripts/ubuntu18", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL") }
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/ubuntu18", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("ubuntu_1804/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								aborted {
									script { awsOps.terminateInstance("${u18_instance_id}", "us-east-1") }
								}
								cleanup {
									script { awsOps.terminateInstance("${u18_instance_id}", "us-east-1") }
								}
							}
						}
					}
				}
				stage('Ubuntu 20.04') {
					stages {
						stage('Script On Server') {
							agent { label 'ubuntu20' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/ubuntu20", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL") }
									u20_instance_id = awsOps.getEC2Metadata("instance-id")
								}
								callScriptOnServer()
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/ubuntu20", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("ubuntu_2004/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								aborted {
									script { awsOps.terminateInstance("${u20_instance_id}", "us-east-1") }
								}
								cleanup {
									script { awsOps.terminateInstance("${u20_instance_id}", "us-east-1") }
								}
							}
						}
						stage('Through Web URL') {
							agent { label 'ubuntu20' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/ubuntu20", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									u20_instance_id = awsOps.getEC2Metadata("instance-id")
								}
								callScriptFromURL()
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "success", context: "setup-scripts/ubuntu20", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL") }
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/ubuntu20", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("ubuntu_2004/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								aborted {
									script { awsOps.terminateInstance("${u20_instance_id}", "us-east-1") }
								}
								cleanup {
									script { awsOps.terminateInstance("${u20_instance_id}", "us-east-1") }
								}
							}
						}
					}
				}
				stage('SLES 12') {
					stages {
						stage('Script On Server') {
							agent { label 'sles12' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/sles12", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL") }
									sles12_instance_id = awsOps.getEC2Metadata("instance-id")
								}
								callScriptOnServer()
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/sles12", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("sles_12/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								aborted {
									script { awsOps.terminateInstance("${sles12_instance_id}", "us-east-1") }
								}
								cleanup {
									script { awsOps.terminateInstance("${sles12_instance_id}", "us-east-1") }
								}
							}
						}
						stage('Through Web URL') {
							agent { label 'sles12' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/sles12", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									sles12_instance_id = awsOps.getEC2Metadata("instance-id")
								}
								callScriptFromURL()
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "success", context: "setup-scripts/sles12", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL") }
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/sles12", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("sles_12/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								aborted {
									script { awsOps.terminateInstance("${sles12_instance_id}", "us-east-1") }
								}
								cleanup {
									script { awsOps.terminateInstance("${sles12_instance_id}", "us-east-1") }
								}
							}
						}
					}
				}
				stage('SLES 15') {
					stages {
						stage('Script On Server') {
							agent { label 'sles15' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/sles15", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL") }
									sles15_instance_id = awsOps.getEC2Metadata("instance-id")
								}
								callScriptOnServer()
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/sles15", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("sles_15/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								aborted {
									script { awsOps.terminateInstance("${sles15_instance_id}", "us-east-1") }
								}
								cleanup {
									script { awsOps.terminateInstance("${sles15_instance_id}", "us-east-1") }
								}
							}
						}
						stage('Through Web URL') {
							agent { label 'sles15' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/sles15", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									sles15_instance_id = awsOps.getEC2Metadata("instance-id")
								}
								callScriptFromURL()
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "success", context: "setup-scripts/sles15", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL") }
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/sles15", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("sles_15/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								aborted {
									script { awsOps.terminateInstance("${sles15_instance_id}", "us-east-1") }
								}
								cleanup {
									script { awsOps.terminateInstance("${sles15_instance_id}", "us-east-1") }
								}
							}
						}
					}
				}
				stage('RHEL 8') {
					stages {
						stage('Script On Server') {
							agent { label 'rhel8' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/rhel8", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL") }
									rhel_instance_id = awsOps.getEC2Metadata("instance-id")
								}
								callScriptOnServer()
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/rhel8", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("rhel_8/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								aborted {
									script { awsOps.terminateInstance("${rhel_instance_id}", "us-east-1") }
								}
								cleanup {
									script { awsOps.terminateInstance("${rhel_instance_id}", "us-east-1") }
								}
							}
						}
						stage('Through Web URL') {
							agent { label 'rhel8' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/rhel8", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									rhel_instance_id = awsOps.getEC2Metadata("instance-id")
								}
								callScriptFromURL()
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "success", context: "setup-scripts/rhel8", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL") }
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/rhel8", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("rhel_8/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								aborted {
									script { awsOps.terminateInstance("${rhel_instance_id}", "us-east-1") }
								}
								cleanup {
									script { awsOps.terminateInstance("${rhel_instance_id}", "us-east-1") }
								}
							}
						}
					}
				}
				stage('CentOS 7') {
					stages {
						stage('Script On Server') {
							agent { label 'centos7' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/centos7", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL") }
									centos_instance_id = awsOps.getEC2Metadata("instance-id")
								}
								callScriptOnServer()
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/centos7", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("centos_7/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								aborted {
									script { awsOps.terminateInstance("${centos_instance_id}", "us-east-1") }
								}
								cleanup {
									script { awsOps.terminateInstance("${centos_instance_id}", "us-east-1") }
								}
							}
						}
						stage('Through Web URL') {
							agent { label 'centos7' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/centos7", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									centos_instance_id = awsOps.getEC2Metadata("instance-id")
								}
								callScriptFromURL()
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "success", context: "setup-scripts/centos7", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL") }
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/centos7", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("centos_7/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								aborted {
									script { awsOps.terminateInstance("${centos_instance_id}", "us-east-1") }
								}
								cleanup {
									script { awsOps.terminateInstance("${centos_instance_id}", "us-east-1") }
								}
							}
						}
					}
				}
			}
			post {
				success {
					script { emailOps.sendSuccessEmail("${committer_email}") }
				}
			}
		}
	}
}


void callScriptFromURL() {
	sh "curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/${(env.CHANGE_ID != null ? pullRequest.head : env.BRANCH_NAME)}/simplerisk-setup.sh | sudo bash -s -- -n -d"
	validateStatusCode()
}

void callScriptOnServer() {
	sh "sudo ./simplerisk-setup.sh -n -d"
	validateStatusCode()
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

void validateStatusCode(String urlToCheck="https://localhost") {
	sh "[ \"\$(curl -s -o /dev/null -w '%{http_code}' -k $urlToCheck)\" = \"200\" ] && exit 0 || exit 1"
}
