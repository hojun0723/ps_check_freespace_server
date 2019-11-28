#==================================================================
#
# Tableau Server 백업/복사 및 시스템 포털 백업, 서버 가용용량 확인
# - 윈도우 서버 용량 확인
# - tableau 서버 백업파일 존재유무 확인
# - 용량 및 백업파일 관련 PUSH 발송
# - 매주 일요일 tableau server cleanup 수행
#
#==================================================================

#메시지 초기화. 에러상태 초기화
$msg = ""
$err = 0

#* 태블로 서버 용량 확인 (알람)
function PushMessage ($P1, $P2, $P3)    #P1: 메시지, P2: 푸쉬유무, P3: 메일유무
{
    # PUSH 서버 접속
    $conn = New-Object System.Data.Odbc.OdbcConnection
    $conn.ConnectionString= "DSN=Cubrid_dsn;"

    $inform_receiver_id = 'user1'
    $inform_date = Get-Date -format "yyyy-MM-dd HH:mm:ss"

    $CrtSQL1 = $(
            '
            INSERT INTO m_inform_temp_for_dw (
            inform_no, 
            inform_system_code, 
            inform_target_company, 
            inform_target_flag, 
            inform_sender_id, 
            inform_receiver_id, 
            inform_push_title, 
            inform_push_content,
            inform_sms_title,
            inform_sms_content,
            inform_mail_title,
            inform_mail_content,
            inform_date,
            push_flag, 
            mail_flag,
            outside_mail_user,
            outside_mail_address,
            outside_sms_user,
            outside_sms_number
            ) 
            VALUES (
            ''3199401'',							--inform_no
            ''DW'',								--inform_system_code
            ''ALL'',								--inform_target_company
            ''P'',								--inform_target_flag
            ''BI서버'',						--inform_sender_id
            '
        )

    $CrtSQL2 = $(
            '
            ''▷ [BI서버상태 알림]'',		--inform_push_title
            '
        )

    $CrtSQL3 = $(
            '
            '''',	--inform_sms_title
            '''',	--inform_sms_content
            ''▷ [BI서버상태 알림]'',	--inform_mail_title
            '
        )

    $CrtSQL4 = $(
            '
            '''',
            '''',
            '''',
            ''''
            );
            '
        )

    $CrtSQL = $CrtSQL1 + '''' + $inform_receiver_id + ''',' + $CrtSQL2 + '''' + $P1 + ''',' + $CrtSQL3 + '''' + $P1.replace("`r`n", "<br>") + ''',' + '''' + $inform_date + ''',' + '''' + $P2 + ''',' + '''' + $P3 + ''',' + $CrtSQL4
    $Cubrid_cmd = new-object System.Data.Odbc.OdbcCommand($CrtSQL,$conn)
    $conn.open()
    $Cubrid_cmd.ExecuteNonQuery()
    $conn.close()
}

#파일 유무 체크
function CheckFile ($P4, $P5) {    #P4: 폴더명, P5: 파일명

    #$BK_FileDate = "2019-10-14"
    $BKfile = Get-ChildItem -Path $P4 -Name *$P5*
    $Len = $BKfile.Length

    if ($Len -eq 0) {         #파일이 존재하지 않는 경우 경로만 표시됨
        $msg = $msg + $P4 + ": " + "백업파일 없음" + "`r`n"
        $err++
    } else {
        $msg = $msg + $P4 + ": " + "백업파일 있음" + "`r`n"
    }
}

$disk = Get-WmiObject Win32_LogicalDisk -ComputerName "BI" -Filter "DeviceID='C:'"
Select-Object Size,FreeSpace

$total1 = "{0:N2}" -f ($disk.Size / 1GB)
$free1 = "{0:N2}" -f ($disk.FreeSpace / 1GB)
$freeratio1 = "{0:N2}" -f (100 - (($disk.FreeSpace / 1GB) / ($disk.Size / 1GB) * 100))
#$total1
#$free1
#$freeratio1

if ($freeratio1 -gt 10) {
    $msg = $msg + "BI서버 C: 여유공간 충분" + "`r`n"
} else {
    $msg = $msg + "BI서버 C: 여유공간 10% 이하" + "`r`n"
    $err++
}

$disk = Get-WmiObject Win32_LogicalDisk -ComputerName "BI" -Filter "DeviceID='D:'"
Select-Object Size,FreeSpace

$total2 = "{0:N2}" -f ($disk.Size / 1GB)
$free2 = "{0:N2}" -f ($disk.FreeSpace / 1GB)
$freeratio2 = "{0:N2}" -f (100 - (($disk.FreeSpace / 1GB) / ($disk.Size / 1GB) * 100))
#$total2
#$free2
#$freeratio2

if ($freeratio2 -gt 10) {
    $msg = $msg + "BI서버 D: 여유공간 충분" + "`r`n"
} else {
    $msg = $msg + "BI서버D: 여유공간 10% 이하" + "`r`n"
    $err++
}

#* 태블로 서버 백업파일 확인 (알람)
#tabserver-2019-10-16.tsbak
#D:\Tableau Server\data\tabsvc\files\backups

$BK_FileDate = Get-Date -UFormat "%Y-%m-%d" ##오늘백업날짜파일 패턴검색용
$FileName = "tabserver-" + $BK_FileDate

#로컬
$SFileFolder = "D:\Tableau Server\data\tabsvc\files\backups"

$BKfile = Get-ChildItem -Path $SFileFolder -Name *$FileName*
$Len = $BKfile.Length

if ($Len -eq 0) {         #파일이 존재하지 않는 경우 경로만 표시됨
    $msg = $msg + $SFileFolder + ": " + "백업파일 없음" + "`r`n"
    $err++
} else {
    $msg = $msg + $SFileFolder + ": " + "백업파일 있음" + "`r`n"
}

#복사본 저장소1
$SFileFolder = "\\remote\folder\"

$BKfile = Get-ChildItem -Path $SFileFolder -Name *$FileName*
$Len = $BKfile.Length

if ($Len -eq 0) {         #파일이 존재하지 않는 경우 경로만 표시됨
    $msg = $msg + $SFileFolder + ": " + "백업파일 없음" + "`r`n"
    $err++
} else {
    $msg = $msg + $SFileFolder + ": " + "백업파일 있음" + "`r`n"
}

#복사본 저장소2
$SFileFolder = "\\remote\folder\"

$BKfile = Get-ChildItem -Path $SFileFolder -Name *$FileName*
$Len = $BKfile.Length

if ($Len -eq 0) {         #파일이 존재하지 않는 경우 경로만 표시됨
    $msg = $msg + $SFileFolder + ": " + "백업파일 없음" + "`r`n"
    $err++
} else {
    $msg = $msg + $SFileFolder + ": " + "백업파일 있음" + "`r`n"
}

if ($err -gt 0) {
    PushMessage $msg "Y" "Y"   
} else {
    PushMessage $msg "N" "Y"   
}

#매주 일요일에 클린업
#if ((get-date).DayOfWeek -eq "Sunday") {
if ((get-date).DayOfWeek -eq "Sunday") {
    tsm maintenance cleanup -l --log-files-retention 14 --u "administrator" -p "password"
} else {
}

#
#* 태블로 서버 리포지토리 접근설정 (선택)
#	tsm data-access repository-access enable --repository-username readonly --repository-password <PASSWORD>
