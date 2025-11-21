[CmdletBinding()]
param (
    [int] $FlashAttention = 1, # 0 = disabled, 1 = enabled
    [string] $KvCacheType = 'q8_0',
    [int] $NumParallel = 6, # number of parallel model inferences
    [int] $MaxLoadedModels = 4, # maximum number of models loaded in GPU memory
    [string] $KeepAlive = '5m0s', # 5 minutes
    [int] $SchedSpread = 1, # 0 = disabled, 1 = enabled
    [int] $GpuOverhead = 524288000, # 500MB
    [int] $MaxQueue = 1024, # maximum number of requests in the queue
    [string] $Models = 'M:\Ollama', # path to models
    [int] $NewEngine = 1, # 0 = disabled, 1 = enabled
    [int] $ContextLength = 65536 # 64k tokens
)
& {
    <#-- INITIALIZATION --#>

    $ErrorActionPreference = 'Stop'
    . "$PSScriptRoot/../Shared.ps1"


    <#-- FUNCTIONS --#>


    <#-- START OF SCRIPT --#>

    Get-Process -Name 'ollama' -ErrorAction SilentlyContinue `
    | ForEach-Object {
        $processId = $_.Id
        $commandLine = $_.CommandLine

        # Check if any arguments match 'serve'
        if ($commandLine -match '\bserve\b') {
            Write-Host "Stopping existing ollama serve process (PID: $processId)..."
            Stop-Process -Id $processId -Force
        }
    }

    $Env:OLLAMA_FLASH_ATTENTION = $FlashAttention
    $Env:OLLAMA_KV_CACHE_TYPE = $KvCacheType
    $Env:OLLAMA_NUM_PARALLEL = $NumParallel
    $Env:OLLAMA_MAX_LOADED_MODELS = $MaxLoadedModels
    $Env:OLLAMA_KEEP_ALIVE = $KeepAlive
    $Env:OLLAMA_SCHED_SPREAD = $SchedSpread
    $Env:OLLAMA_GPU_OVERHEAD = $GpuOverhead
    $Env:OLLAMA_MAX_QUEUE = $MaxQueue
    $Env:OLLAMA_MODELS = $Models
    $Env:OLLAMA_NEW_ENGINE = $NewEngine
    $Env:OLLAMA_CONTEXT_LENGTH = $ContextLength

    ollama serve
}
