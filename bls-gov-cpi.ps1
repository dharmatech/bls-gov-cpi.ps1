
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

$data_all    = get-bls-gov 'CUSR0000SA0'
$data_food   = get-bls-gov 'CUSR0000SAF1'

# SAF11	Food at home
# SEFV	Food away from home

$data_energy = get-bls-gov 'CUSR0000SA0E'
# SACE	Energy commodities
$data_gasoline = get-bls-gov 'CUSR0000SETB01' # SETB01	Gasoline (all types)
# SEHE01	Fuel oil
# SEHF	Energy services
# SEHF01	Electricity
# SEHF02	Utility (piped) gas service

$data_core   = get-bls-gov 'CUSR0000SA0L1E'

# SACL1E	Commodities less food and energy commodities
$data_new_vehicles         = get-bls-gov 'CUSR0000SETA01' # SETA01	New vehicles
$data_used_cars_and_trucks = get-bls-gov 'CUSR0000SETA02' # SETA02	Used cars and trucks

# SAA	Apparel
# SAM1	Medical care commodities
# SASLE	Services less energy services
$data_shelter   = get-bls-gov 'CUSR0000SAH1' # SAH1	Shelter
# SAS4	Transportation services
# SAM2	Medical care services

# --------------------------------------------------------------------------------

$table = for ($i = 1; $i -lt $data_all.Count; $i++)
{
    [pscustomobject]@{
        year = $data_all[$i].year
        periodName = $data_all[$i].periodName
        all  = $data_all[$i].percent_change.ToString('N1')
        core = $data_core[$i].percent_change.ToString('N1')
        food = $data_food[$i].percent_change.ToString('N1')
        energy = $data_energy[$i].percent_change.ToString('N1')
        gasoline = $data_gasoline[$i].percent_change.ToString('N1')
        new_vehicles = $data_new_vehicles[$i].percent_change.ToString('N1')
        used_cars_and_trucks = $data_used_cars_and_trucks[$i].percent_change.ToString('N1')
        shelter = $data_shelter[$i].percent_change.ToString('N1')        
    }
}

function color ($val)
{
    if ($val -gt 0) { 'Green' } elseif ($val -lt 0) { 'Red' } else { 'White' }
}

#            2023 February       0.4    0.4   -0.6    0.5           0.2    0.8
$header =   '                    all   food energy    gas   core    veh   used   shel'

Write-Host $header

for ($i = 1; $i -lt $table.Count; $i++)
{
    function change ($name) { $table[$i].$name - $table[$i-1].$name }

    function entry ($name)
    {
        Write-Host ('{0,7}' -f $table[$i].$name) -ForegroundColor (color (change $name)) -NoNewline
    }
            
    Write-Host ('{0} {1,-10} ' -f $table[$i].year, $table[$i].periodName) -NoNewline

    entry 'all'
    entry 'food'
    entry 'energy'
    entry 'gasoline'
    entry 'core'
    entry 'new_vehicles'
    entry 'used_cars_and_trucks'
    entry 'shelter'

    Write-Host
}

Write-Host $header

# ----------------------------------------------------------------------

function dataset ($name)
{
    @{ label = $name; data = $table.ForEach({ $_.$name }); lineTension = 0; fill = $fill }
}

$fill = $false

$json = @{
    chart = @{
        type = 'line'
        data = @{

            labels = $table | ForEach-Object { Get-Date ('{0} {1}' -f $_.year, $_.periodName.Substring(0,3)) -Format 'yyyy-MM-dd' }

            datasets = @(
                dataset 'all'
                dataset 'food'
                dataset 'energy'
                dataset 'gasoline'
                dataset 'core'
                dataset 'new_vehicles'
                dataset 'used_cars_and_trucks'
                dataset 'shelter'
            )
        }
        options = @{
            
            title = @{ display = $true; text = 'CPI : monthly percent changes (seasonally adjusted)' }

            scales = @{ }
        }
    }
} | ConvertTo-Json -Depth 100

$result = Invoke-RestMethod -Method Post -Uri 'https://quickchart.io/chart/create' -Body $json -ContentType 'application/json'

$id = ([System.Uri] $result.url).Segments[-1]

Start-Process ('https://quickchart.io/chart-maker/view/{0}' -f $id)

exit
# ----------------------------------------------------------------------

.\bls-gov-cpi.ps1 -api_key (Get-Content C:\Users\dharm\Dropbox\api-keys\bls-gov)

# ----------------------------------------------------------------------

$data_all | Select-Object *, @{ Label = 'yoy'; Expression = { 0 } } | ft *

for ($i = 12; $i -lt $data_all.Count; $i++)
{
    '{0} {1}    {2} {3}' -f $data_all[$i-12].year, $data_all[$i-12].period, $data_all[$i].year, $data_all[$i].period
}

# ----------------------------------------------------------------------
$data_all_nsa = get-bls-gov 'CUUR0000SA0'

foreach ($elt in $data_all_nsa)
{
    $elt | Add-Member -MemberType NoteProperty -Name yoy -Value $null -Force
}

for ($i = 12; $i -lt $data_all_nsa.Count; $i++)
{
    $val = [math]::Round((percent-change $data_all_nsa[$i-12].value $data_all_nsa[$i].value), 1)

    $data_all_nsa[$i] | Add-Member -MemberType NoteProperty -Name yoy -Value $val -Force
}

$data_all_nsa | ft *
# ----------------------------------------------------------------------
$data_core_nsa = get-bls-gov 'CUUR0000SA0L1E'

foreach ($elt in $data_core_nsa)
{
    $elt | Add-Member -MemberType NoteProperty -Name yoy -Value $null -Force
}

for ($i = 12; $i -lt $data_core_nsa.Count; $i++)
{
    $val = [math]::Round((percent-change $data_core_nsa[$i-12].value $data_core_nsa[$i].value), 1)

    $data_core_nsa[$i] | Add-Member -MemberType NoteProperty -Name yoy -Value $val -Force
}

$data_core_nsa | ft *
# ----------------------------------------------------------------------
$json = @{
    chart = @{
        type = 'line'
        data = @{
            
            labels = $data_all_nsa | Select-Object -Skip 12 | ForEach-Object { Get-Date ('{0} {1}' -f $_.year, $_.periodName.Substring(0,3)) -Format 'yyyy-MM-dd' }

            datasets = @(
                @{ type = 'bar' ; label = 'all' ; data = $data_all_nsa  | Select-Object -Skip 12 | ForEach-Object yoy; fill = $false }
                @{ type = 'line'; label = 'core'; data = $data_core_nsa | Select-Object -Skip 12 | ForEach-Object yoy; fill = $false }
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