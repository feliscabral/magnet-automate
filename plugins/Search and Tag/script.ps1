Start-Sleep -seconds 1
# -----------------------------------------------------------------------------
# Magnet Forensics AUTOMATE v3.x Plugin
# by FELIS CABRAL
# February 16, 2024
# -----------------------------------------------------------------------------
# Script Variables
# -----------------------------------------------
$script_name        = "Search and Tag"
$script_version     = "1.1"
$script_description = "Search evidence and tag results"
$script_enabled     = "${SAT_ENABLED}"        #true|false
$output_log         = "${SAT_OUTPUT_LOG}"     #true|false
$empty_tag          = "${SAT_EMPTY_TAG}"      #true|false
$no_result_fail     = "${SAT_NO_RESULT_FAIL}" #true|false
$case_path          = "${SAT_CASE_PATH}"
$tag_name           = "${SAT_TAG_NAME}"
$tag_color          = "${SAT_TAG_COLOR}"
$definition_name    = "${SAT_DEFINITION_NAME}"
$operation          = "${SAT_OPERATION}"
$definition_value   = "${SAT_DEFINITION_VALUE}"
$temp_path          = "${OUTPUT_PATH}"

# -----------------------------------------------
# Log Function
# -----------------------------------------------
function LogThis($text) {
    $message = "[$script_name] $((Get-Date).ToString("yyyy-MM-dd-hh:mm:ss")) $text"
    Write-Host "$message"
    if($output_log -eq "true"){
        try {
            Write-Output "$message" >> "$temp_path\log.txt"
        }
        catch {
            Write-Host "CANNOT CREATE LOG FILE! - $_"
        }
    }
}
LogThis("----------------------------------------------------------------------------------------------")
LogThis(" Script Name : $script_name v$script_version")
LogThis(" Description : $script_description")
LogThis(" Node        : $env:computername")
LogThis("----------------------------------------------------------------------------------------------")
LogThis("             Enabled : $script_enabled")
LogThis("          Output Log : $output_log")
LogThis("    Create Empty Tag : $empty_tag")
LogThis(" Exit 1 if no result : $no_result_fail")
LogThis("           Case Path : $case_path")
LogThis("            Tag Name : $tag_name")
LogThis("           Tag Color : $tag_color")
LogThis("     Definition Name : $definition_name")
LogThis("           Operation : $operation")
LogThis("    Definition Value : $definition_value")
LogThis("           Temp Path : $temp_path")
LogThis("----------------------------------------------------------------------------------------------")

# -----------------------------------------------
# Exit With Desired Code Function
# -----------------------------------------------
function ExitWithDesiredCode(){
    #end script with desired code
    if($no_result_fail -eq "true"){
        LogThis("Exting with code 1"); exit(1)
    } else {
        LogThis("Exiting with code 0"); exit(0)
    }
}

# -----------------------------------------------
# Validate Variables
# -----------------------------------------------
if($script_enabled -ne "true") { LogThis("Script is not enabled. Exiting with code 0"); Exit(0) }
if($definition_value -eq "") { LogThis("Definition Value / search word(s) not provided or empty! Search will NOT executed."); ExitWithDesiredCode }
if(-not (Test-Path -Path "$temp_path")) { LogThis("Temp path does not exist! Exiting with code 1"); exit(1) }
if(-not (Test-Path -Path "$case_path")) { LogThis("Case path does not exist! Exiting with code 1"); exit(1) }
# Look for Case.mfdb
$case_file = $case_path + "\Case.mfdb"
if(-not (Test-Path -PathType Leaf "$case_file")) { LogThis("Case.mfdb does not exist! Exiting with code 1"); exit(1) }

$date_range_example = "2023-01-01T00:00:00Z to 2023-12-31T11:59:59Z"

# -----------------------------------------------
# Check if definition value is a logical file
# -----------------------------------------------
if(Test-Path -Path $definition_value -PathType Leaf){    
    #For Dates ONLY - only need the first line if it's a date ragne.
    if($definition_name -eq "DATE-RANGE"){
        try {
            $definition_value = Get-Content "$definition_value" -First 1
            LogThis("Definition Value is a logical file and loaded [$definition_value]")
        } catch {
            LogThis("Definition Value provided is a logical file but cannot be read. Expecting plain text file with dates on first line.")
            ExitWithDesiredCode
        }
    } else {
        try {
            $definition_value = Get-Content "$definition_value"
            $count = $definition_value.count
            LogThis("Definition Value is a logical file and loaded $count values.")
        } catch {
            LogThis("Definition Value provided is a logical file but cannot be read. Expecting plain text file with one value in each line.")
            ExitWithDesiredCode
        }
    }
}

# -----------------------------------------------
# Validate Tag Color
# -----------------------------------------------
$valid_color = 0
switch($tag_color) {
    "[random]"   { $valid_color = 1 }
    "Green"      { $tag_color = "-8323328";  $valid_color = 1 }
    "Red"        { $tag_color = "-2555904";  $valid_color = 1 }
    "Yellow"     { $tag_color = "-137137";   $valid_color = 1 }
    "Orange"     { $tag_color = "-32768";    $valid_color = 1 }
    "Violete"    { $tag_color = "-5878273";  $valid_color = 1 }
    "Blue"       { $tag_color = "-11699457"; $valid_color = 1 }
    "Light Blue" { $tag_color = "-11676929"; $valid_color = 1 }
    "Pink"       { $tag_color = "-45569";    $valid_color = 1 }
}
if($valid_color -ne 1) {
    LogThis("Unknown color '$tag_color' using 'Green' instead.")
    $tag_color = "-8323328"
}

# -----------------------------------------------
# Locate SQLite3.exe
# -----------------------------------------------
# Locate SQLite3 Relative to the nodes AXIOM Process CLI path
$sqlite3 = split-path -parent "${AXIOM_PROCESS_PATH}"
$sqlite3 = split-path -parent $sqlite3
$sqlite3 = $sqlite3 + "\web\lib\sqlite3.exe"
# Make sure sqlite.exe exist
if(Test-Path -Path $sqlite3 -PathType Leaf){ LogThis("sqlite3.exe found in $sqlite3") } else { LogThis("Cannot find sqlite3.exe. Exiting with code 1"); Exit(1) }

# -----------------------------------------------
# SQL Query Function
# -----------------------------------------------
function sql_query($sql) {
    # Add double backslashes
    $case_file = $case_file.Replace('\','\\')
    # Create the .sql file with query
    $content = ".open `"$case_file`"`n$sql"
    $content | Out-File -FilePath "$temp_path\query.sql" -Encoding ascii
    # Create a batch file to run the sql
    $batch_content = "`"$sqlite3`" < `"$temp_path\query.sql`""
    $batch_content | Out-File -FilePath "$temp_path\\run_query.bat" -Encoding ascii
    # Execute the process -> Output result
    start-process -FilePath "$temp_path\\run_query.bat" -RedirectStandardOutput "$temp_path\\sql_output.txt" -NoNewWindow -Wait
    # this will return an obect if more than 1
    $result = (get-content "$temp_path\\sql_output.txt" | Select-Object -Skip 2 )
    #delete temp files
    remove-item -Path "$temp_path\query.sql" -Force
    remove-item -Path "$temp_path\run_query.bat" -Force
    remove-item -Path "$temp_path\sql_output.txt" -Force
    return $result
}

# -----------------------------------------------
# Add Tag Function
# -----------------------------------------------
function Add-Tag($tag_name) {
    $tag_id = sql_query("SELECT tag_id FROM tag WHERE tag_name = '$tag_name'")
    if($tag_id){
        #LogThis("Tag name '$tag_name' already exist.") #use existing tag
        $case_tag_id = sql_query("SELECT case_tag_id FROM case_tag WHERE tag_id = '$tag_id' LIMIT 1;")
        return $case_tag_id
    } else {
        LogThis("Creating Tag '$tag_name'")
        #Create row inside tag table.
        $tag_id = New-Guid; $tag_id = $tag_id.ToString("N")
        #If tag color is random
        if($tag_color -eq "[random]"){ $tag_color = @(-8323328, -2555904, -137137,-32768, -5878273, -11699457, -11676929, -45569 ) | Get-Random }
        #Execute creation of tag
        sql_query("INSERT INTO tag (tag_id,tag_name,tag_color,tag_type) VALUES('$tag_id','$tag_name',$tag_color,'User');")
        #Create row inside case_tag table.
        $case_tag_id = New-Guid; $case_tag_id = $case_tag_id.ToString("N")
        $case_info_id = sql_query("SELECT case_info_id FROM case_info LIMIT 1")
        sql_query("INSERT INTO case_tag (case_tag_id,case_info_id,tag_id) VALUES('$case_tag_id','$case_info_id','$tag_id');")
        return $case_tag_id
    }
}

# -------------------------------------
# String Dates to Unix Time Stamps
# -------------------------------------
function InvalidDate($string){
    LogThis("Invalid date format provided [$string]")
    LogThis("$date_range_example")
    ExitWithDesiredCode
}
function StringDate2Unix($string){
    $string = $string.ToLower()
    #required keywords
    if(-not($string.contains("to"))){
        InvalidDate("execting a date range with the word `"to`" between two dates")
        return $false
    }
    $date0 = Get-Date -Date "01/01/1970"
    $string = $string.Replace(" to ", "|")
    $string = $string.split("|").Trim()
    try{$date1 = (Get-Date -Date $string[0]).ToUniversalTime()} catch {InvalidDate("$string - $_")}
    try{$date2 = (Get-Date -Date $string[1]).ToUniversalTime()} catch {InvalidDate("$string - $_")}
    $span = @()
    $span += (New-TimeSpan -Start $date0 -End $date1).TotalSeconds
    $span += (New-TimeSpan -Start $date0 -End $date2).TotalSeconds
    return $span
}

# -----------------------------------------------
# Execute Query / Get Hits Function
# -----------------------------------------------
function SearchThisWord($word) {
    # ----------------------
    # Build SQL Query Operator and Query
    # ----------------------
    $operation_valid = 0
    switch($operation) {
        "begins with"  { $definition_operator = "LIKE";     $word = "$word%'";   $operation_valid = 1 }
        "ends with"    { $definition_operator = "LIKE";     $word = "'%$word'";  $operation_valid = 1 }
        "contains"     { $definition_operator = "LIKE";     $word = "'%$word%'"; $operation_valid = 1 }
        "not contains" { $definition_operator = "NOT LIKE"; $word = "'%$word%'"; $operation_valid = 1 }
        "equals"       { $definition_operator = "=";        $word = "'$word'";   $operation_valid = 1 }
        "not equals"   { $definition_operator = "!=";       $word = "'$word'";   $operation_valid = 1 }
    } 
    # ----------------------
    # Execute SQL Search
    # ----------------------
    if($operation_valid -eq 0) { LogThis("Unknown operation '$operation' exiting with code 1"); Exit(1) }
    if($definition_name -eq "PREVIEW") {
        #------------
        #query the fragment_content table / file and email attachment content
        #------------
        $sql = "SELECT hit_fragment_id FROM fragment_content WHERE content $definition_operator $word;"
        $hit_ids = sql_query($sql)
        #convert hit_ids to hit_fragment_id (from the hit_fragment_string table)
        $sql = ""
        foreach($hit_id in $hit_ids) {
            $sql += "SELECT hit_id FROM hit_fragment_string WHERE hit_fragment_id = '$hit_id';"
        }
        $hit_ids = sql_query($sql)
    }
    #------------
    #query hit_fragment_string table / email body / metadata / columns
    #------------
    if($definition_name -ne "PREVIEW" -and $definition_name -ne "DATE-RANGE" -and $definition_name -ne "Artifact type") {
        # Get all artifact_ids because there may be multiple for each one!
        $definition_ids = sql_query("SELECT fragment_definition_id FROM fragment_definition WHERE name LIKE '$definition_name';")
        if($definition_ids.count -eq 0) {LogThis("Definition Name [$definition_name] not found in Case! Skipping..."); break} #<----------------- CHECK THIS LATER!
        # Build query for each artifact id
        $sql_left = "SELECT hit_id FROM hit_fragment_string WHERE ("
        $count = 0
        foreach($definition_id in $definition_ids){
            $count ++
            $sql_middle += "fragment_definition_id = '$definition_id'"
            if($count -ne $definition_ids.Count) {$sql_middle+=" OR "}
        }
        $sql_right = ") AND value $definition_operator $word;"
        $sql = "$sql_left$sql_middle$sql_right"
        $hit_ids = sql_query($sql)
    }
    #------------
    # Execute SQL Date Range
    #------------
    if($definition_name -eq "DATE-RANGE"){
        $word = $word.replace("%","")
        $word = $word.replace("'","")
        $range = StringDate2UNIX($word)
        LogThis("Searching date range in UNIX time [$range]")
        $date1 = $range[0]
        $date2 = $range[1]
        $sql = "SELECT hit_id FROM hit_fragment_date WHERE unix_timestamp BETWEEN $date1  AND $date2"
        $hit_ids = sql_query($sql)
    }
    

    #------------
    # Execute SQL Artifact type
    #------------
    if($definition_name -eq "Artifact type") {
        # Get all artifact_ids
        $artifact_id = sql_query("SELECT artifact_id FROM artifact WHERE artifact_name = $word;")
        if($artifact_id.count -eq 0) {LogThis("Definition Name (Artifact type) [$word] not found in Case! Skipping..."); return }       
        # Get artifact version_id
        $artifact_version_ids = sql_query("SELECT artifact_version_id FROM artifact_version WHERE artifact_id = '$artifact_id';")
        # Build query for each artifact id
        $sql_left = "SELECT hit_id FROM scan_artifact_hit WHERE "
        foreach($artifact_version_id in $artifact_version_ids){
            $sql_middle += "artifact_version_id = '$artifact_version_id'"
        }
        $sql_right = ";"
        $sql = "$sql_left$sql_middle$sql_right"
        $hit_ids = sql_query($sql)
    }
    return $hit_ids
}

# -----------------------------------------------
# Function to Create tag and associate hit_id(s)
# -----------------------------------------------
function CreateTagAndAssociate($tag_name, $hit_ids){
    $case_tag_id = Add-Tag($tag_name)
    foreach($hit_id in $hit_ids) { $sql += "INSERT INTO hit_case_tag ('hit_id','case_tag_id') VALUES($hit_id,'$case_tag_id');" }
    $dummy = sql_query($sql) #execute association
}



# -----------------------------------------------
# Call Function to Execute Query for each word
# -----------------------------------------------
$words = $definition_value.split(",").Trim()
foreach($word in $words){
    $hit_ids = SearchThisWord($word)
    $hit_ids = $hit_ids | Select-Object -Unique #dedupe
    $hit_count = $hit_ids.count
    $total_ids += $hit_ids
    LogThis("Found $hit_count artifact(s) for ""$word""")
    if($hit_ids.count -gt 0){
        $new_tag_name = $tag_name.Replace("@value",$word)
        CreateTagAndAssociate $new_tag_name $hit_ids
    } else {
        if($empty_tag -eq "false"){
            LogThis("Tag not created for ""$word"".")
        } else {
            $dummy = Add-Tag($tag_name) #create tag
        }
    }
}

# -----------------------------------------------
# Final Results
# -----------------------------------------------
LogThis("TOTAL Artifacts Found: " + $total_ids.count)
$total_unique_ids = $total_ids | Select-Object -Unique #dedupe
LogThis("TOTAL Unique Artifacts Tagged: " + $total_unique_ids.count)
if($total_unique_ids -lt 1){
    LogThis("No hits.")
    ExitWithDesiredCode
}
LogThis("All done.")
LogThis("Exiting with code 0")
Exit(0)