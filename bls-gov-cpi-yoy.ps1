
Param($api_key)

function reverse
{ 
    $arr = @($input)
    [array]::reverse($arr)
    $arr
}

function percent-change ($a, $b)
{
    # ($b - $a) / $a

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

# ----------------------------------------------------------------------
$data_all_nsa = get-bls-gov 'CUUR0000SA0'

add-null-property $data_all_nsa 'yoy'

add-yoy-property $data_all_nsa

# $data_all_nsa | ft *
# ----------------------------------------------------------------------
$data_core_nsa = get-bls-gov 'CUUR0000SA0L1E'

add-null-property $data_core_nsa 'yoy'

add-yoy-property $data_core_nsa

# $data_core_nsa | ft *
# ----------------------------------------------------------------------
$data_shelter_nsa = get-bls-gov 'CUUR0000SAH1'

add-null-property $data_shelter_nsa 'yoy'

add-yoy-property $data_shelter_nsa


# $data_shelter   = get-bls-gov 'CUSR0000SAH1' # SAH1	Shelter
# ----------------------------------------------------------------------
$data = get-bls-gov 'CUUR0000SAF1';     add-null-property $data 'yoy';   add-yoy-property $data;   $data_food_nsa = $data
$data = get-bls-gov 'CUUR0000SEHF01';   add-null-property $data 'yoy';   add-yoy-property $data;   $data_electricity_nsa = $data
# ----------------------------------------------------------------------
$json = @{
    chart = @{
        type = 'line'
        data = @{
            
            labels = $data_all_nsa | Select-Object -Skip 12 | ForEach-Object { Get-Date ('{0} {1}' -f $_.year, $_.periodName.Substring(0,3)) -Format 'yyyy-MM-dd' }

            datasets = @(
                @{ type = 'bar' ; label = 'all'           ; data = $data_all_nsa            | Select-Object -Skip 12 | ForEach-Object yoy; fill = $false }
                @{ type = 'line'; label = 'core'          ; data = $data_core_nsa           | Select-Object -Skip 12 | ForEach-Object yoy; fill = $false }
                @{ type = 'line'; label = 'shelter'       ; data = $data_shelter_nsa        | Select-Object -Skip 12 | ForEach-Object yoy; fill = $false }
                @{ type = 'line'; label = 'food'          ; data = $data_food_nsa           | Select-Object -Skip 12 | ForEach-Object yoy; fill = $false }
                @{ type = 'line'; label = 'electricity'   ; data = $data_electricity_nsa    | Select-Object -Skip 12 | ForEach-Object yoy; fill = $false }
            )
        }
        options = @{
            
            title = @{ display = $true; text = 'CPI : year-over-year percent changes (not seasonally adjusted)' }

            scales = @{ 
                yAxes = @(
                    @{
                        ticks = @{
                            beginAtZero = $true
                        }
                    }
                )
            }
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

# ----------------------------------------------------------------------

$data_all | Select-Object *, @{ Label = 'yoy'; Expression = { 0 } } | ft *

for ($i = 12; $i -lt $data_all.Count; $i++)
{
    '{0} {1}    {2} {3}' -f $data_all[$i-12].year, $data_all[$i-12].period, $data_all[$i].year, $data_all[$i].period
}

