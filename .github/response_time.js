module.exports = async ({github, context}, start_days_back, end_days_back) => {
    let start_date = new Date();
    start_date.setDate(start_date.getDate() - Number(start_days_back));
    let end_date = new Date();
    end_date.setDate(end_date.getDate() - Number(end_days_back));
    const regex = /\n\n<!-- probot = (.*) -->/;
    const opts = github.rest.issues.listForRepo.endpoint.merge({
        ...context.issue,
        state: 'all',
        since: start_date.toString()
    })
    const issues = await github.paginate(opts)
    let issueCount = 0
    let responseTimeSum = 0
    let untriagedIssueCount = 0
    for (const issue of issues) {
        const issueOpenedDate = new Date(issue.created_at);
        if (end_date < issueOpenedDate) {
            continue;
        }
        let body = issue.body
        if (!body) {
            body = (await github.rest.issues.get(issue)).data.body || ''
        }
        let match = body.match(regex)
        if (match) {
            let onesignalMetadata = JSON.parse(match[1])['onesignal-probot']
            if (onesignalMetadata) {
                let responseTime = onesignalMetadata['response_time_in_business_days'];
                // Only include issues that have been responded to.
                if (!(responseTime == null || responseTime === '')) {
                    responseTimeSum += responseTime
                    issueCount += 1
                    console.log(responseTime)
                    continue;
                }
            }
        }
        untriagedIssueCount += 1
    }
    const responseTimeAverage = responseTimeSum / issueCount
    const roundedResponseTimeAverageString = Math.round((responseTimeAverage + Number.EPSILON) * 100) / 100;
    const resultString = "Issue response time average: " + roundedResponseTimeAverageString + " business days from " + start_days_back + " to " + end_days_back + " days ago with " + untriagedIssueCount + " issues waiting for a response."
    console.log(resultString)
    return resultString
}