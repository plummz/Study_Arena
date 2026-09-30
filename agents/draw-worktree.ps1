Add-Type -AssemblyName System.Drawing
$w=2600; $h=1820
$bmp=[System.Drawing.Bitmap]::new($w,$h)
$g=[System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode='AntiAlias'
$g.Clear([System.Drawing.Color]::FromArgb(246,248,252))
$dark=[System.Drawing.Brushes]::MidnightBlue
$ink=[System.Drawing.Brushes]::Black
$white=[System.Drawing.Brushes]::White
$font=[System.Drawing.Font]::new('Segoe UI',20,[System.Drawing.FontStyle]::Regular)
$small=[System.Drawing.Font]::new('Segoe UI',16,[System.Drawing.FontStyle]::Regular)
$bold=[System.Drawing.Font]::new('Segoe UI',23,[System.Drawing.FontStyle]::Bold)
$title=[System.Drawing.Font]::new('Segoe UI',38,[System.Drawing.FontStyle]::Bold)
$pen=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(78,97,130),4)
$arrow=[System.Drawing.Drawing2D.AdjustableArrowCap]::new(7,7)
$pen.CustomEndCap=$arrow
function box($x,$y,$bw,$bh,$label,$color,$fs=$font) {
 $b=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($color))
 $g.FillRectangle($b,$x,$y,$bw,$bh)
 $g.DrawRectangle([System.Drawing.Pens]::SlateGray,$x,$y,$bw,$bh)
 $fmt=[System.Drawing.StringFormat]::new();$fmt.Alignment='Center';$fmt.LineAlignment='Center'
 $g.DrawString($label,$fs,$white,[System.Drawing.RectangleF]::new($x+8,$y+5,$bw-16,$bh-10),$fmt)
 $fmt.Dispose();$b.Dispose()
}
function line($x1,$y1,$x2,$y2){$g.DrawLine($pen,$x1,$y1,$x2,$y2)}
$g.DrawString('Study Arena agent worktree',$title,$dark,70,35)
$g.DrawString('Local repository | heads review specialists | independent quality gates before Done',$font,$ink,74,100)
box 950 155 700 95 'PROGRAM MANAGER: scope / flow / deadlines / risks / evidence' '#15365b' $bold
$heads=@(
 @{x=60; t='LEARNING / PRODUCT HEAD'; c='#245d72'; s=@('Student feedback','Learning experience research','Content / curriculum')},
 @{x=570; t='DESIGN HEAD'; c='#62518c'; s=@('UX writing','UX design','Visual design','Interaction design','Accessibility')},
 @{x=1080; t='ENGINEERING HEAD'; c='#265e56'; s=@('Engineering','Security / privacy')},
 @{x=1590; t='QUALITY HEAD'; c='#8a4b4e'; s=@('QA testing','Independent verification','Code review')},
 @{x=2100; t='PM DIRECT REPORTS'; c='#4c668e'; s=@('Work intake','Website / app progress','Creative + AI app coordinator')}
)
foreach($head in $heads){
 $x=$head.x
 line 1300 250 ($x+220) 315
 box $x 320 440 84 $head.t $head.c $bold
 $y=435
 foreach($s in $head.s){line ($x+220) ($y-31) ($x+220) $y;box ($x+15) $y 410 80 $s '#536783' $font;$y+=112}
}
$y=1180
$g.DrawString('HANDOFF PATH',$bold,$dark,70,$y)
$stages=@('Intake + scope','Research + design','Implementation','Head review','Independent verification','QA + code review','PM closes')
$x=65
foreach($s in $stages){box $x ($y+70) 330 100 $s '#254c70' $font;if($x -gt 65){line ($x-35) ($y+120) ($x-5) ($y+120)};$x+=360}
$g.DrawString('Findings return to the owner; security/privacy review applies to sensitive changes. No Done without evidence.', $font,$ink,70,1430)
$g.DrawString('Browse instructions: agents/README.md     Tasks: agents/TASK_BOARD.md     Feature labels: agents/FEATURE_MAP.md',$font,$ink,70,1480)
$g.DrawString('Current is not production ready  |  Planned is not live  |  Unverified is not passed',$bold,$dark,70,1570)
$out=Join-Path $PSScriptRoot 'Study-Arena-Agent-Worktree.jpg'
$bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Jpeg)
$g.Dispose();$bmp.Dispose();$font.Dispose();$small.Dispose();$bold.Dispose();$title.Dispose();$pen.Dispose();$arrow.Dispose()
Write-Output $out
