
Param($api_key, $precision = 1)

function reverse
{ 
    $arr = @($input)
    [array]::reverse($arr)
    $arr
}

function percent-change ($a, $b)
{
    ($b - $a) / $a * 100
}

# https://www.bls.gov/help/hlpforma.htm#CU

# https://download.bls.gov/pub/time.series/cu/cu.item
                                                                                  

# $result = Invoke-RestMethod -Uri ('https://api.bls.gov/publicAPI/v1/timeseries/data/{0}' -f 'CUSR0000SA0L1E')

# $api_key = Get-Content C:\Users\dharm\Dropbox\api-keys\bls-gov

# $result = Invoke-RestMethod -Uri ('https://api.bls.gov/publicAPI/v2/timeseries/data/{0}?registrationkey={1}' -f 'CUSR0000SA0L1E', $api_key)

# --------------------------------------------------------------------------------

function get-bls-gov ($series)
{
    $result = if ($api_key -eq $null)
    {
        Invoke-RestMethod -Uri ('https://api.bls.gov/publicAPI/v2/timeseries/data/{0}' -f $series)
    }
    else
    {
        Write-Host ('Retrieving {0} using API key' -f $series) -ForegroundColor Yellow

        Invoke-RestMethod -Uri ('https://api.bls.gov/publicAPI/v2/timeseries/data/{0}?registrationkey={1}' -f $series, $api_key)
    }
    
    $data = $result.Results.series[0].data | Where-Object 'periodName' -NE 'Annual' | reverse
    
    for ($i = 1; $i -lt $data.Count; $i++)
    {
        $data[$i] | Add-Member -MemberType NoteProperty -Name percent_change -Value (percent-change $data[$i-1].value $data[$i].value)     
    }
    
    $data    
}

# https://data.bls.gov/cgi-bin/surveymost?cu

# https://download.bls.gov/pub/time.series/cu/cu.item
# ----------------------------------------------------------------------

function add-null-property ($data, $name)
{
    foreach ($elt in $data)
    {
        $elt | Add-Member -MemberType NoteProperty -Name $name -Value $null -Force
    }    
}

function add-yoy-property ($data)
{
    for ($i = 12; $i -lt $data.Count; $i++)
    {
        $val = [math]::Round((percent-change $data[$i-12].value $data[$i].value), 1)
    
        $data[$i] | Add-Member -MemberType NoteProperty -Name yoy -Value $val -Force
    }    
}

function add-mom-property ($data)
{
    for ($i = 1; $i -lt $data.Count; $i++)
    {
        $val = [math]::Round((percent-change $data[$i-1].value $data[$i].value), $precision)
            
        $data[$i] | Add-Member -MemberType NoteProperty -Name mom -Value $val -Force
    }    
}

# ----------------------------------------------------------------------

$data = get-bls-gov 'CUSR0000SA0';    add-null-property $data 'mom'; add-mom-property $data; $data_all_sa = $data
$data = get-bls-gov 'CUSR0000SA0L1E'; add-null-property $data 'mom'; add-mom-property $data; $data_core_sa = $data
$data = get-bls-gov 'CUSR0000SA0E';   add-null-property $data 'mom'; add-mom-property $data; $data_energy = $data
$data = get-bls-gov 'CUSR0000SAH1';   add-null-property $data 'mom'; add-mom-property $data; $data_shelter = $data
$data = get-bls-gov 'CUSR0000SETA01'; add-null-property $data 'mom'; add-mom-property $data; $data_new_vehicles = $data
$data = get-bls-gov 'CUSR0000SETA02'; add-null-property $data 'mom'; add-mom-property $data; $data_used_cars_and_trucks = $data
$data = get-bls-gov 'CUSR0000SAF1';   add-null-property $data 'mom'; add-mom-property $data; $data_food = $data

# ----------------------------------------------------------------------

# $data_all_sa | ft *

$table = for ($i = 0; $i -lt $data_all_sa.Count; $i++)
{
    [PSCustomObject]@{
        date                 = Get-Date ('{0} {1}' -f $data_all_sa[$i].year, $data_all_sa[$i].periodName.Substring(0,3)) -Format 'yyyy-MM-dd'
        all              = $data_all_sa[$i].mom
        core             = $data_core_sa[$i].mom
        energy               = $data_energy[$i].mom
        shelter              = $data_shelter[$i].mom
        new_vehicles         = $data_new_vehicles[$i].mom
        used_cars_and_trucks = $data_used_cars_and_trucks[$i].mom
        food                 = $data_food[$i].mom
    }
}
# ----------------------------------------------------------------------
function delta ($table, $a, $b)
{
    if ($b -eq $null)
    {
        $b = '{0}_change' -f $a
    }

    $prev = $table[0]

    foreach ($elt in $table | Select-Object -Skip 1)
    {
        $change = $elt.$a - $prev.$a

        $elt | Select-Object *, @{ Label = $b; Expression = { $change } }

        $prev = $elt
    }
}

$table = delta $table all
$table = delta $table core
$table = delta $table energy              
$table = delta $table shelter             
$table = delta $table new_vehicles        
$table = delta $table used_cars_and_trucks
$table = delta $table food                

# ----------------------------------------------------------------------
# function colored-change-val ($val)
# {
#     $val = [math]::Round($val, 1)        

#         if ($val -gt 0) { $color = '32' }
#     elseif ($val -lt 0) { $color = '31' }
#     else                { $color = '0' }

#     $e = [char]27

#     $formatted = $val.ToString('N1')

#     "$e[${color}m$($formatted)${e}[0m"    
# }



function colored-val ($row, $name)
{
    $change = $row."$($name)_change"

    $change = [math]::Round($change, 1)        

        if ($change -gt 0) { $color = '32' }
    elseif ($change -lt 0) { $color = '31' }
    else                   { $color = '0' }
   
    $e = [char]27

    $val = $row.$name

    $formatted = $val.ToString('N1')

    "$e[${color}m$($formatted)${e}[0m"    
}


$row = $table[1]

$name = 'all'

colored-val $table[1] all

# function colored-change-val ($val)
# {
        

#         if ($val -gt 0) { $color = '32' }
#     elseif ($val -lt 0) { $color = '31' }
#     else                { $color = '0' }

#     $e = [char]27

#     $formatted = $val.ToString('N1')

#     "$e[${color}m$($formatted)${e}[0m"    
# }

# $table | Format-Table date, 
#     @{
#         Label = 'all_change'

#         Expression = { colored-change-val $_.all_change }

#         Align = 'right'
#     }

function gen-field ($name)
{
    @{
        Label = $name
        Expression = $name
        Format = 'N1'
        Align = 'right'
    }    
}

# function gen-change-field ($name)
# {
#     $name = '{0}_change' -f $name

#     @{
#         Label = $name
#         Expression = [System.Management.Automation.ScriptBlock]::Create('colored-change-val $_.{0}' -f $name)
#         # Format = 'N1'
#         Align = 'right'
#     }    
# }


function gen-colored-field ($name)
{
    # $name = '{0}_change' -f $name

    @{
        Label = $name
        Expression = [System.Management.Automation.ScriptBlock]::Create('colored-val $_ {0}' -f $name)
        # Format = 'N1'
        Align = 'right'
    }    
}





# $fields = @(
#     'date'
#     (gen-field 'all'),              (gen-change-field 'all')
#     (gen-field 'core'),             (gen-change-field 'core')
#     (gen-field 'energy'),               (gen-change-field 'energy')
#     (gen-field 'shelter'),              (gen-change-field 'shelter')
#     (gen-field 'new_vehicles'),         (gen-change-field 'new_vehicles')
#     (gen-field 'used_cars_and_trucks'), (gen-change-field 'used_cars_and_trucks')
#     (gen-field 'food'),                 (gen-change-field 'food')
# )


$fields = @(
    'date'
    (gen-colored-field 'all')
    (gen-colored-field 'core')
    (gen-colored-field 'energy')
    (gen-colored-field 'shelter')
    (gen-colored-field 'new_vehicles')
    (gen-colored-field 'used_cars_and_trucks')
    (gen-colored-field 'food')
)

$fields[1].Expression


# $table | Format-Table date, all, (gen-field 'all_change'), core, (gen-field 'core_change')

$table | Format-Table $fields

$table

# ----------------------------------------------------------------------
# $data_all_nsa = get-bls-gov 'CUUR0000SA0'

# add-null-property $data_all_nsa 'yoy'

# add-yoy-property $data_all_nsa

# $data_all_nsa | ft *
# ----------------------------------------------------------------------
# $data_core_nsa = get-bls-gov 'CUUR0000SA0L1E'

# add-null-property $data_core_nsa 'yoy'

# add-yoy-property $data_core_nsa

# $data_core_nsa | ft *
# ----------------------------------------------------------------------
# $data_shelter_nsa = get-bls-gov 'CUUR0000SAH1'

# add-null-property $data_shelter_nsa 'yoy'

# add-yoy-property $data_shelter_nsa

# $data_shelter   = get-bls-gov 'CUSR0000SAH1' # SAH1	Shelter
# ----------------------------------------------------------------------
# $data = get-bls-gov 'CUUR0000SAF1';     add-null-property $data 'yoy';   add-yoy-property $data;   $data_food_nsa = $data
# $data = get-bls-gov 'CUUR0000SEHF01';   add-null-property $data 'yoy';   add-yoy-property $data;   $data_electricity_nsa = $data
# ----------------------------------------------------------------------


# $data_all_sa | Select-Object -Skip 1  | ForEach-Object { $_.mom.ToString('N1') }

# $data_all_sa | Select-Object -Skip 1  | ForEach-Object { [math]::Round($_.mom,2) }

$json = @{
    chart = @{
        type = 'line'
        data = @{
            
            # labels = $data_all_nsa | Select-Object -Skip 12 | ForEach-Object { Get-Date ('{0} {1}' -f $_.year, $_.periodName.Substring(0,3)) -Format 'yyyy-MM-dd' }

            labels = $data_all_sa | Select-Object -Skip 1 | ForEach-Object { Get-Date ('{0} {1}' -f $_.year, $_.periodName.Substring(0,3)) -Format 'yyyy-MM-dd' }

            datasets = @(
                @{ type = 'bar' ; label = 'all'                  ; data = $data_all_sa               | Select-Object -Skip 1  | ForEach-Object mom; fill = $false; lineTension = 0 }
                @{ type = 'line'; label = 'core'                 ; data = $data_core_sa              | Select-Object -Skip 1  | ForEach-Object mom; fill = $false; lineTension = 0 }
                @{ type = 'line'; label = 'energy'               ; data = $data_energy               | Select-Object -Skip 1  | ForEach-Object mom; fill = $false; lineTension = 0; hidden = $true }
                @{ type = 'line'; label = 'shelter'              ; data = $data_shelter              | Select-Object -Skip 1  | ForEach-Object mom; fill = $false; lineTension = 0; hidden = $true }
                @{ type = 'line'; label = 'new_vehicles'         ; data = $data_new_vehicles         | Select-Object -Skip 1  | ForEach-Object mom; fill = $false; lineTension = 0; hidden = $true }
                @{ type = 'line'; label = 'used_cars_and_trucks' ; data = $data_used_cars_and_trucks | Select-Object -Skip 1  | ForEach-Object mom; fill = $false; lineTension = 0; hidden = $true }
                @{ type = 'line'; label = 'food'                 ; data = $data_food                 | Select-Object -Skip 1  | ForEach-Object mom; fill = $false; lineTension = 0; hidden = $true }
                
                # @{ type = 'line'; label = 'shelter'       ; data = $data_shelter_nsa        | Select-Object -Skip 12 | ForEach-Object yoy; fill = $false }
                # @{ type = 'line'; label = 'food'          ; data = $data_food_nsa           | Select-Object -Skip 12 | ForEach-Object yoy; fill = $false }
                # @{ type = 'line'; label = 'electricity'   ; data = $data_electricity_nsa    | Select-Object -Skip 12 | ForEach-Object yoy; fill = $false }
            )
        }
        options = @{
            
            title = @{ display = $true; text = 'CPI : MoM percent changes (seasonally adjusted)' }

            scales = @{ yAxes = @( @{ ticks = @{ beginAtZero = $true } } ) }
        }
    }
} | ConvertTo-Json -Depth 100

$result = Invoke-RestMethod -Method Post -Uri 'https://quickchart.io/chart/create' -Body $json -ContentType 'application/json'

$id = ([System.Uri] $result.url).Segments[-1]

Start-Process ('https://quickchart.io/chart-maker/view/{0}' -f $id)
# ----------------------------------------------------------------------
exit
# ----------------------------------------------------------------------

# .\bls-gov-cpi.ps1 -api_key (Get-Content C:\Users\dharm\Dropbox\api-keys\bls-gov)

. .\bls-gov-cpi-yoy.ps1 -api_key (Get-Content C:\Users\dharm\Dropbox\api-keys\bls-gov)

.\bls-gov-cpi-mom.ps1 -api_key (Get-Content C:\Users\dharm\Dropbox\api-keys\bls-gov)

# ----------------------------------------------------------------------

$data_all | Select-Object *, @{ Label = 'yoy'; Expression = { 0 } } | ft *

for ($i = 12; $i -lt $data_all.Count; $i++)
{
    '{0} {1}    {2} {3}' -f $data_all[$i-12].year, $data_all[$i-12].period, $data_all[$i].year, $data_all[$i].period
}

