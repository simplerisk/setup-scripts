@Library('simplerisk') _

pipeline {
	agent none
	stages {
		stage("Initializing Common Variables") {
			agent { label "terminator" }
			steps {
				script {
					committer_email = gitOps.getCommitterEmail()
					script_commit = (env.CHANGE_ID != null ? pullRequest.head : env.BRANCH_NAME)
				}
			}
			post {
				failure { 
					script { emailOps.sendErrorEmail("${env.STAGE_NAME}", "${committer_email}") }
				}
			}
		}
		stage("Setup Script Deployment") {
			parallel {
				stage("Debian 11") {
					stages {
						stage("Script On Server") {
							agent { label "debian11" }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/debian11", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL") }
									d11_instance_id = awsOps.getEC2Metadata("instance-id")
									miscOps.callScriptOnServer()
								}
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/debian11", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("debian_11/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								cleanup {
									script { awsOps.terminateInstance("${d11_instance_id}", true) }
								}
							}
						}
						stage("Through Web URL") {
							agent { label "debian11" }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/debian11", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									d11_instance_id = awsOps.getEC2Metadata("instance-id")
									miscOps.callScriptFromURL("$script_commit")
								}
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "success", context: "setup-scripts/debian11", description: "SimpleRisk installed successfully.", targetUrl: "$BUILD_URL") }
									}
								}
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/debian11", description: "Couldn't install SimpleRisk through URL.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("debian_11/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								cleanup {
									script { awsOps.terminateInstance("${d11_instance_id}") }
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
									sh "sleep 2m"
									miscOps.callScriptOnServer()
								}
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/ubuntu18", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("ubuntu_1804/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								cleanup {
									script { awsOps.terminateInstance("${u18_instance_id}", true) }
								}
							}
						}
						stage("Through Web URL") {
							agent { label "ubuntu18" }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/ubuntu18", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									u18_instance_id = awsOps.getEC2Metadata("instance-id")
									sh "sleep 2m"
									miscOps.callScriptFromURL("$script_commit")
								}
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
								cleanup {
									script { awsOps.terminateInstance("${u18_instance_id}") }
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
									miscOps.callScriptOnServer()
								}
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/ubuntu20", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("ubuntu_2004/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								cleanup {
									script { awsOps.terminateInstance("${u20_instance_id}", true) }
								}
							}
						}
						stage('Through Web URL') {
							agent { label 'ubuntu20' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/ubuntu20", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									u20_instance_id = awsOps.getEC2Metadata("instance-id")
									miscOps.callScriptFromURL("$script_commit")
								}
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
								cleanup {
									script { awsOps.terminateInstance("${u20_instance_id}") }
								}
							}
						}
					}
				}
				stage("Ubuntu 22.04") {
					stages {
						stage("Script On Server") {
							agent { label "ubuntu22" }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/ubuntu18", description: "Installing SimpleRisk through script on server...", targetUrl: "$BUILD_URL") }
									u22_instance_id = awsOps.getEC2Metadata("instance-id")
									miscOps.callScriptOnServer()
								}
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/ubuntu18", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("ubuntu_2204/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								cleanup {
									script { awsOps.terminateInstance("${u22_instance_id}", true) }
								}
							}
						}
						stage("Through Web URL") {
							agent { label "ubuntu22" }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/ubuntu18", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									u22_instance_id = awsOps.getEC2Metadata("instance-id")
									sh "sleep 2m"
									miscOps.callScriptFromURL("$script_commit")
								}
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
										emailOps.sendErrorEmail("ubuntu_2204/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								cleanup {
									script { awsOps.terminateInstance("${u22_instance_id}") }
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
									miscOps.callScriptOnServer()
								}
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/sles12", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("sles_12/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								cleanup {
									script { awsOps.terminateInstance("${sles12_instance_id}", true) }
								}
							}
						}
						stage('Through Web URL') {
							agent { label 'sles12' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/sles12", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									sles12_instance_id = awsOps.getEC2Metadata("instance-id")
									miscOps.callScriptFromURL("$script_commit")
								}
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
								cleanup {
									script { awsOps.terminateInstance("${sles12_instance_id}") }
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
									miscOps.callScriptOnServer()
								}
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/sles15", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("sles_15/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								cleanup {
									script { awsOps.terminateInstance("${sles15_instance_id}", true) }
								}
							}
						}
						stage('Through Web URL') {
							agent { label 'sles15' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/sles15", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									sles15_instance_id = awsOps.getEC2Metadata("instance-id")
									miscOps.callScriptFromURL("$script_commit")
								}
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
								cleanup {
									script { awsOps.terminateInstance("${sles15_instance_id}") }
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
									miscOps.callScriptOnServer()
								}
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/rhel8", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("rhel_8/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								cleanup {
									script { awsOps.terminateInstance("${rhel_instance_id}", true) }
								}
							}
						}
						stage('Through Web URL') {
							agent { label 'rhel8' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/rhel8", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									rhel_instance_id = awsOps.getEC2Metadata("instance-id")
									miscOps.callScriptFromURL("$script_commit")
								}
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
								cleanup {
									script { awsOps.terminateInstance("${rhel_instance_id}") }
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
									miscOps.callScriptOnServer()
								}
							}
							post {
								failure {
									script {
										if (env.CHANGE_ID) { pullRequest.createStatus(status: "failure", context: "setup-scripts/centos7", description: "Couldn't install SimpleRisk through script on server.", targetUrl: "$BUILD_URL") }
										emailOps.sendErrorEmail("centos_7/${env.STAGE_NAME}", "${committer_email}")
									}
								}
								cleanup {
									script { awsOps.terminateInstance("${centos_instance_id}", true) }
								}
							}
						}
						stage('Through Web URL') {
							agent { label 'centos7' }
							steps {
								script {
									if (env.CHANGE_ID) { pullRequest.createStatus(status: "pending", context: "setup-scripts/centos7", description: "Installing SimpleRisk through URL...", targetUrl: "$BUILD_URL") }
									centos_instance_id = awsOps.getEC2Metadata("instance-id")
									miscOps.callScriptFromURL("$script_commit")
								}
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
								cleanup {
									script { awsOps.terminateInstance("${centos_instance_id}") }
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
