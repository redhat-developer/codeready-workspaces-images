def JOB_BRANCHES = ["2.7":"7.26.x", "2.8":"7.28.x", "2.x":"master"] // TODO when che server moves to main as its default branch, change this too
def JOB_DISABLED = ["2.7":true, "2.8":true, "2.x":false]
for (JB in JOB_BRANCHES) {
    SOURCE_BRANCH=JB.value
    JOB_BRANCH=""+JB.key
    MIDSTM_BRANCH="crw-" + JOB_BRANCH.replaceAll(".x","") + "-rhel-8"
    jobPath="${FOLDER_PATH}/${ITEM_NAME}_" + JOB_BRANCH
    pipelineJob(jobPath){
        disabled(JOB_DISABLED[JB.key]) // on reload of job, disable to avoid churn
        UPSTM_NAME="che"
        UPSTM_REPO="https://github.com/eclipse/" + UPSTM_NAME

        description('''
Artifact builder + sync job; triggers brew after syncing

<ul>
<li>Upstream: <a href=''' + UPSTM_REPO + '''>''' + UPSTM_NAME + ''' server</a></li>
<li>Midstream: <a href=https://github.com/redhat-developer/codeready-workspaces/tree/''' + MIDSTM_BRANCH + '''/>crw server</a></li>
<li>Downstream: <a href=http://pkgs.devel.redhat.com/cgit/containers/codeready-workspaces?h=''' + MIDSTM_BRANCH + '''>crw server</a></li>
</ul>

<p>If <b style="color:green">downstream job fires</b>, see <a href=../get-sources-rhpkg-container-build_''' + JOB_BRANCH + '''/>get-sources-rhpkg-container-build</a>. <br/>
   If <b style="color:orange">job is yellow</b>, no changes found to push, so no container-build triggered. </p>
        ''')

        properties {
            ownership {
                primaryOwnerId("nboldt")
            }

            pipelineTriggers {
                triggers{
                    pollSCM{
                        scmpoll_spec("H H/8 * * *") // every 8hrs
                    }
                }
            }

            disableResumeJobProperty()
        }

        logRotator {
            daysToKeep(5)
            numToKeep(5)
            artifactDaysToKeep(2)
            artifactNumToKeep(1)
        }

        parameters{
            stringParam("SOURCE_BRANCH", SOURCE_BRANCH)
            stringParam("MIDSTM_BRANCH", MIDSTM_BRANCH)
            booleanParam("FORCE_BUILD", false, "If true, trigger a rebuild even if no changes were pushed to pkgs.devel")
        }

        // Trigger builds remotely (e.g., from scripts), using Authentication Token = CI_BUILD
        authenticationToken('CI_BUILD')

        definition {
            cps{
                sandbox(true)
                script(readFileFromWorkspace('jobs/CRW_CI/crw-server_'+JOB_BRANCH+'.jenkinsfile'))
            }
        }
    }
}