pipeline {
	agent none
	stages {
		stage("Setup Script Deployment") {
			parallel {
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
								ubuntuReconfiguredpkg()
								callScriptOnServer()
							}
							post {
								always {
									node("jenkins") {
										terminateInstance("${u18_instance_id}", "us-east-1")
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/ubuntu18", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL")
										}
									}
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
								ubuntuReconfiguredpkg()
								callScriptFromURL()
							}
							post {
								always {
									node("jenkins") {
										terminateInstance("${u18_instance_id}", "us-east-1")
									}
								}
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
										}
									}
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
								ubuntuReconfiguredpkg()
								callScriptOnServer()
							}
							post {
								always {
									node("jenkins") {
										terminateInstance("${u20_instance_id}", "us-east-1")
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/ubuntu20", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL")
										}
									}
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
								ubuntuReconfiguredpkg()
								callScriptFromURL()
							}
							post {
								always {
									node("jenkins") {
										terminateInstance("${u20_instance_id}", "us-east-1")
									}
								}
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
										}
									}
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
								callScriptOnServer()
							}
							post {
								always {
									node("jenkins") {
										terminateInstance("${sles12_instance_id}", "us-east-1")
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/sles12", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL")
										}
									}
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
								callScriptFromURL()
							}
							post {
								always {
									node("jenkins") {
										terminateInstance("${sles12_instance_id}", "us-east-1")
									}
								}
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
										}
									}
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
								always {
									node("jenkins") {
										terminateInstance("${sles15_instance_id}", "us-east-1")
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/sles15", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL")
										}
									}
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
								always {
									node("jenkins") {
										terminateInstance("${sles15_instance_id}", "us-east-1")
									}
								}
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
										}
									}
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
								always {
									node("jenkins") {
										terminateInstance("${rhel_instance_id}", "us-east-1")
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/rhel8", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL")
										}
									}
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
								always {
									node("jenkins") {
										terminateInstance("${rhel_instance_id}", "us-east-1")
									}
								}
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
										}
									}
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
								always {
									node("jenkins") {
										terminateInstance("${centos_instance_id}", "us-east-1")
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "failure", context: "setup-scripts/centos7", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL")
										}
									}
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
								always {
									node("jenkins") {
										terminateInstance("${centos_instance_id}", "us-east-1")
									}
								}
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
										}
									}
								}
							}
						}
						stage("Discard Server (2)") {
							agent {
								label "jenkins"
							}
							steps {
								terminateInstance("${centos_instance_id}", "us-east-1", 5)
							}
						}
					}
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
	sh "aws ec2 terminate-instances --instance-ids $instanceId --region $region"
	sh "sleep $number"
}

void callScriptFromURL() {
	sh "curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/${(env.CHANGE_ID != null ? pullRequest.head : env.BRANCH_NAME)}/simplerisk-setup.sh | sudo bash -s -- -n -d"
	validateStatusCode()
}

void validateStatusCode(String urlToCheck="https://localhost") {
	sh "[ \"\$(curl -s -o /dev/null -w '%{http_code}' -k $urlToCheck)\" = \"200\" ] && exit 0 || exit 1"
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
