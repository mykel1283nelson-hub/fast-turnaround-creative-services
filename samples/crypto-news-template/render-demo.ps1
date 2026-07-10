param(
    [string]$DataPath = (Join-Path $PSScriptRoot 'demo-data.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot 'crypto-news-template-demo.mp4')
)

$ErrorActionPreference = 'Stop'

$ffmpeg = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\.tools\python\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe')
$data = Get-Content -LiteralPath $DataPath -Raw -Encoding UTF8 | ConvertFrom-Json
$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}

function Escape-Drawtext {
    param([string]$Value)

    return $Value.Replace('\', '\\').Replace("'", "\'").Replace(':', '\:')
}

$regularFont = 'C\:/Windows/Fonts/segoeui.ttf'
$boldFont = 'C\:/Windows/Fonts/segoeuib.ttf'
$accent = $data.accent -replace '[^0-9A-Fa-f]', ''
if ($accent.Length -ne 6) {
    throw 'accent must contain exactly six hexadecimal characters'
}

$label = Escape-Drawtext $data.label
$eyebrow = Escape-Drawtext $data.eyebrow
$headlineLine1 = Escape-Drawtext $data.headlineLine1
$headlineLine2 = Escape-Drawtext $data.headlineLine2
$ticker = Escape-Drawtext $data.ticker
$price = Escape-Drawtext $data.price
$change = Escape-Drawtext $data.change
$summary1 = Escape-Drawtext $data.summary1
$summary2 = Escape-Drawtext $data.summary2
$summary3 = Escape-Drawtext $data.summary3
$source = Escape-Drawtext $data.source
$cta = Escape-Drawtext $data.cta

$filters = @(
    "drawbox=x=0:y=0:w=iw:h=ih:color=0x071013:t=fill",
    "drawbox=x=64:y=64:w=952:h=1792:color=0x0C191D:t=fill",
    "drawbox=x=64:y=64:w=12:h=1792:color=0x${accent}:t=fill",
    "drawtext=fontfile='$boldFont':text='$eyebrow':fontcolor=0x${accent}:fontsize=34:x=104:y=106",
    "drawtext=fontfile='$regularFont':text='$label':fontcolor=0xB7C5C2:fontsize=25:x=104:y=161",
    "drawtext=fontfile='$regularFont':text='12 SEC / 9\:16 / JSON INPUT':fontcolor=0x70817D:fontsize=24:x=620:y=112",
    "drawbox=x=104:y=252:w=872:h=2:color=0x233438:t=fill",
    "drawtext=fontfile='$boldFont':text='$headlineLine1':fontcolor=0xF4F8F7:fontsize=126:x=104:y=410:enable='between(t,0,3)'",
    "drawtext=fontfile='$boldFont':text='$headlineLine2':fontcolor=0x${accent}:fontsize=126:x=104:y=555:enable='between(t,0,3)'",
    "drawtext=fontfile='$regularFont':text='HEADLINE + TICKER + PRICE + SUMMARY':fontcolor=0x9DB0AC:fontsize=33:x=108:y=775:enable='between(t,0,3)'",
    "drawbox=x=104:y=850:w=872:h=180:color=0x12252A:t=fill:enable='between(t,0,3)'",
    "drawtext=fontfile='$boldFont':text='ONE TEMPLATE':fontcolor=0xF4F8F7:fontsize=54:x=144:y=895:enable='between(t,0,3)'",
    "drawtext=fontfile='$regularFont':text='Swap data. Render. Publish.':fontcolor=0xB7C5C2:fontsize=36:x=144:y=965:enable='between(t,0,3)'",
    "drawtext=fontfile='$regularFont':text='$ticker':fontcolor=0x9DB0AC:fontsize=40:x=108:y=365:enable='between(t,3,6)'",
    "drawtext=fontfile='$boldFont':text='$price':fontcolor=0xF4F8F7:fontsize=142:x=104:y=455:enable='between(t,3,6)'",
    "drawbox=x=104:y=640:w=270:h=86:color=0x${accent}:t=fill:enable='between(t,3,6)'",
    "drawtext=fontfile='$boldFont':text='$change':fontcolor=0x071013:fontsize=48:x=140:y=658:enable='between(t,3,6)'",
    "drawtext=fontfile='$regularFont':text='24H MOVE':fontcolor=0x9DB0AC:fontsize=29:x=400:y=675:enable='between(t,3,6)'",
    "drawbox=x=108:y=960:w=110:h=360:color=0x1A3439:t=fill:enable='between(t,3,6)'",
    "drawbox=x=246:y=900:w=110:h=420:color=0x235047:t=fill:enable='between(t,3,6)'",
    "drawbox=x=384:y=780:w=110:h=540:color=0x2B6E55:t=fill:enable='between(t,3,6)'",
    "drawbox=x=522:y=670:w=110:h=650:color=0x348B63:t=fill:enable='between(t,3,6)'",
    "drawbox=x=660:y=560:w=110:h=760:color=0x3CA971:t=fill:enable='between(t,3,6)'",
    "drawbox=x=798:y=430:w=110:h=890:color=0x${accent}:t=fill:enable='between(t,3,6)'",
    "drawtext=fontfile='$regularFont':text='ILLUSTRATIVE TREND / NOT LIVE DATA':fontcolor=0x70817D:fontsize=25:x=108:y=1380:enable='between(t,3,6)'",
    "drawtext=fontfile='$boldFont':text='WHY IT MOVED':fontcolor=0xF4F8F7:fontsize=76:x=104:y=355:enable='between(t,6,9)'",
    "drawbox=x=104:y=500:w=872:h=152:color=0x12252A:t=fill:enable='between(t,6,9)'",
    "drawtext=fontfile='$boldFont':text='01':fontcolor=0x${accent}:fontsize=48:x=142:y=548:enable='between(t,6,9)'",
    "drawtext=fontfile='$regularFont':text='$summary1':fontcolor=0xF4F8F7:fontsize=43:x=250:y=555:enable='between(t,6,9)'",
    "drawbox=x=104:y=686:w=872:h=152:color=0x12252A:t=fill:enable='between(t,6,9)'",
    "drawtext=fontfile='$boldFont':text='02':fontcolor=0x${accent}:fontsize=48:x=142:y=734:enable='between(t,6,9)'",
    "drawtext=fontfile='$regularFont':text='$summary2':fontcolor=0xF4F8F7:fontsize=43:x=250:y=741:enable='between(t,6,9)'",
    "drawbox=x=104:y=872:w=872:h=152:color=0x12252A:t=fill:enable='between(t,6,9)'",
    "drawtext=fontfile='$boldFont':text='03':fontcolor=0x${accent}:fontsize=48:x=142:y=920:enable='between(t,6,9)'",
    "drawtext=fontfile='$regularFont':text='$summary3':fontcolor=0xF4F8F7:fontsize=43:x=250:y=927:enable='between(t,6,9)'",
    "drawtext=fontfile='$regularFont':text='$source':fontcolor=0x70817D:fontsize=28:x=108:y=1120:enable='between(t,6,9)'",
    "drawtext=fontfile='$boldFont':text='$cta':fontcolor=0xF4F8F7:fontsize=86:x=(w-text_w)/2:y=430:enable='between(t,9,12)'",
    "drawtext=fontfile='$regularFont':text='headline / price / change':fontcolor=0x${accent}:fontsize=40:x=(w-text_w)/2:y=620:enable='between(t,9,12)'",
    "drawtext=fontfile='$regularFont':text='summary / source / image':fontcolor=0x${accent}:fontsize=40:x=(w-text_w)/2:y=690:enable='between(t,9,12)'",
    "drawtext=fontfile='$regularFont':text='JSON IN':fontcolor=0x9DB0AC:fontsize=30:x=205:y=905:enable='between(t,9,12)'",
    "drawtext=fontfile='$boldFont':text='TO':fontcolor=0x${accent}:fontsize=44:x=495:y=898:enable='between(t,9,12)'",
    "drawtext=fontfile='$regularFont':text='MP4 OUT':fontcolor=0x9DB0AC:fontsize=30:x=665:y=905:enable='between(t,9,12)'",
    "drawbox=x=104:y=1090:w=872:h=170:color=0x${accent}:t=fill:enable='between(t,9,12)'",
    "drawtext=fontfile='$boldFont':text='NO MANUAL TIMELINE':fontcolor=0x071013:fontsize=52:x=(w-text_w)/2:y=1145:enable='between(t,9,12)'",
    "fade=t=in:st=0:d=0.25",
    "fade=t=out:st=11.65:d=0.35",
    "format=yuv420p"
) -join ','
$filters = $filters.Replace('drawtext=fontfile=', 'drawtext=expansion=none:fontfile=')

$renderArgs = @(
    '-hide_banner', '-loglevel', 'warning', '-y',
    '-f', 'lavfi', '-i', 'color=c=0x071013:s=1080x1920:r=30:d=12',
    '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
    '-filter_complex', "[0:v]$filters[v]",
    '-map', '[v]', '-map', '1:a', '-t', '12', '-shortest',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
    '-c:a', 'aac', '-b:a', '96k', '-movflags', '+faststart',
    $OutputPath
)

& $ffmpeg @renderArgs
if ($LASTEXITCODE -ne 0) {
    throw "ffmpeg render failed with exit code $LASTEXITCODE"
}

$contactSheetPath = Join-Path $outputDirectory 'contact-sheet.jpg'
$sheetArgs = @(
    '-hide_banner', '-loglevel', 'warning', '-y', '-i', $OutputPath,
    '-vf', "select='eq(n\,30)+eq(n\,120)+eq(n\,210)+eq(n\,300)',scale=270:480,tile=4x1",
    '-frames:v', '1', '-q:v', '2', $contactSheetPath
)

& $ffmpeg @sheetArgs
if ($LASTEXITCODE -ne 0) {
    throw "contact-sheet render failed with exit code $LASTEXITCODE"
}

Write-Output $OutputPath
Write-Output $contactSheetPath
