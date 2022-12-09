<#
  .EXAMPLE

  # Get all GitHub repositories of the Azure organization
  ./Get-GitHubRepositories.ps1 -Owner 'Azure'

  # Login as 'robinet' and get all repositories of 'MyPrivateOrg'
  ./Get-GitHubRepositories.ps1 -Owner 'MyPrivateOrg' -ProfileName 'robinet'
#>

param (
  [string] $Owner = $(throw 'Owner is required')
  , [string] $ProfileName = $null
)

Push-Location $PSScriptRoot
try {
  ./Set-GitHubConnection.ps1 -ProfileName $ProfileName
  $fields = @('assignableUsers',
    'codeOfConduct',
    'contactLinks',
    'createdAt',
    'defaultBranchRef',
    'deleteBranchOnMerge',
    'description',
    'diskUsage',
    'forkCount',
    'fundingLinks',
    'hasIssuesEnabled',
    'hasProjectsEnabled',
    'hasWikiEnabled',
    'homepageUrl',
    'id',
    'isArchived',
    'isBlankIssuesEnabled',
    'isEmpty',
    'isFork',
    'isInOrganization',
    'isMirror',
    'isPrivate',
    'isSecurityPolicyEnabled',
    'isTemplate',
    'isUserConfigurationRepository',
    'issueTemplates',
    'issues',
    'labels',
    'languages',
    'latestRelease',
    'licenseInfo',
    'mentionableUsers',
    'mergeCommitAllowed',
    'milestones',
    'mirrorUrl',
    'name',
    'nameWithOwner',
    'openGraphImageUrl',
    'owner',
    'parent',
    'primaryLanguage',
    'projects',
    'pullRequestTemplates',
    'pullRequests',
    'pushedAt',
    'rebaseMergeAllowed',
    'repositoryTopics',
    'securityPolicyUrl',
    'squashMergeAllowed',
    'sshUrl',
    'stargazerCount',
    'templateRepository',
    'updatedAt',
    'url',
    'usesCustomOpenGraphImage',
    'viewerCanAdminister',
    'viewerDefaultCommitEmail',
    'viewerDefaultMergeMethod',
    'viewerHasStarred',
    'viewerPermission',
    'viewerPossibleCommitEmails',
    'viewerSubscription',
    'watchers')
  return $(gh repo list $Owner --json "$($fields -join ',')") | ConvertFrom-Json -Depth 100
} finally {
  Pop-Location
}


