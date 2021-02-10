pipeline {
	agent none
	stages {
		stage('Deployment Testing Through Local Script') {
			parallel {
				stage('Ubuntu 18.04') {
					agent {
						label 'ubuntu18'
					}
					steps {
						sh '''
							sudo ./simplerisk-setup.sh -n -d
						'''
					}
				}
				stage('Ubuntu 20.04') {
					agent {
						label 'ubuntu20'
					}
					steps {
						sh '''
							sudo ./simplerisk-setup.sh -n -d
						'''
					}
				}
				stage('RHEL 8') {
					agent {
						label 'rhel8'
					}
					steps {
						sh '''
							sudo ./simplerisk-setup.sh -n -d
						'''
					}
				}
				stage('CentOS 7') {
					agent {
						label 'centos7'
					}
					steps {
						sh '''
							sudo ./simplerisk-setup.sh -n -d
						'''
					}
				}

			}
		}
		//stage('Deployment Testing Through Web Page') {
		//}
	}
}
