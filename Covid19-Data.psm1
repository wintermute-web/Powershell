
function Get-DaysInLockdown{

    [DateTime]$start = "23 March 2020"
    [DateTime]$today = Get-Date 

    $daysInLockdown = $today - $start

    $daysView = $daysInLockdown | Select-Object  -ExpandProperty Days 
    
    return $daysView   

}

function Get-Cases{

    param(

        [string]$Country
    )

    $headers=@{}
    $headers.Add("x-rapidapi-host", "covid-193.p.rapidapi.com")
    $headers.Add("x-rapidapi-key", "56135d0f0dmshe43ede3f1c57ba4p16ac9fjsnf43b7663248c")
    

    # get the api results.  If there's an issue try testing the net connection.
    try{
        
            $response = Invoke-RestMethod -Uri "https://covid-193.p.rapidapi.com/statistics?country=$Country" -Method GET -Headers $headers
            $responseAll = Invoke-RestMethod -Uri 'https://covid-193.p.rapidapi.com/statistics?country=ALL' -Method GET -Headers $headers
        
    }catch{

        $connection = Test-NetConnection -InformationLevel Quiet

        if ( $connection -eq "True"){

            Write-Host "Internet connection is up, but API for COVID-19 stats cannot be reached" -ForegroundColor Red

        }else{

            Write-Host "API for COVID-19 stats cannot be reached, Internet connection may be down" -ForegroundColor Red

        }

    }

        $args = @{
            "world" = $responseAll.response.cases.active
            "worldRecovered" = $responseAll.response.cases.recovered
            "worldDeaths" = $responseAll.response.deaths.total
            "new" = $response.response.cases.new;
            "active" = $response.response.cases.active;
            "critical" = $response.response.cases.critical;
            "recovered" = $response.response.cases.recovered;
            "total" = $response.response.cases.total;
            "deaths" = $response.response.deaths.total;
            "newDeaths" = $response.response.deaths.new;
        }

    $Stats = New-Object -TypeName PSObject -ArgumentList $args

    return $Stats
}

function Show-Chart{

    
    [int]$cases = (Get-Cases -Country $Country).total
    [int]$newCases = (Get-Cases -Country $Country).new
    [int]$deaths = (Get-Cases -Country $Country).deaths
    [int]$recovered = (Get-Cases -Country $Country).recovered
    

    # to keep chart length sensible, increase the divisor *10
    if($cases -lt 15000){

        $divisor = 100

    }else{

        $divisor = 1000
    }

    # round up so that we always show a plot point if the number is > 0
    [int]$casesConverted = [Math]::Round([Math]::Ceiling($cases / $divisor))
    [int]$newCasesConverted = [Math]::Round([Math]::Ceiling($newCases / $divisor))
    [int]$deathsConverted = [Math]::Round([Math]::Ceiling($deaths / $divisor))
    [int]$recoveredConverted = [Math]::Round([Math]::Ceiling($recovered / $divisor))

    [string]$casesPlot = "c" * $casesConverted
    [string]$newCasesPlot = "n" * $newCasesConverted
    [string]$deathsPlot = "d" * $deathsConverted
    [string]$recoveredPlot = "r" * $recoveredConverted

    $args = @{

        "plottedCases" = $casesPlot;
        "plottednewCases" = $newCasesPlot;
        "plottedDeaths" = $deathsPlot;
        "plottedRecovered" = $recoveredPlot;
        "divisor" = $divisor
    }

    $plottedStats = New-Object -TypeName PSObject -ArgumentList $args

    return $plottedStats

}

function Show-COVIDCases{

    <#
    .SYNOPSIS
    Queries an API for COVID-19 world and country specific data
    .DESCRIPTION
    Queries an API for COVID-19 world and country specific data
    .PARAMETER WindowsChart
    Switch to show a GUI chart of data or not.
    .PARAMETER Country
    String to display data for a given country.  If no country is given
    only world data will be shown 
    .EXAMPLE
    Show-COVIDCases  -Country "Spain" -WindowsChart
    Shows the COVID-19 cases for the world and Spain, and displays a GUI 
    chart. 
    .EXAMPLE
    Show-COVIDCases  -Country "UK"
    Shows the COVID-19 data for the world and the UK. 
    .EXAMPLE
    Show-COVIDCases
    Shows world COVID-19 data.
    #>

    [cmdletBinding()]


    param(
        [Parameter()]
        [switch]$WindowsChart,
        
        [Parameter(Mandatory=$True,
            ValueFromPipeline=$True, 
            ValueFromPipelineByPropertyName=$True,
            ParameterSetName='Country'
        )]
        [string]$Country
    )

    #region write preamble
    Clear-Host
    Write-Host
    Write-Host "Fetching coronavirus stats..."
    Write-Host
    #endregion

    #region gather the numbers

    # get world data
    [int]$worldCases = (Get-Cases).world
    [int]$worldRecovered = (Get-Cases).worldRecovered
    [float]$worldPercentageRecovered = [math]::Round((($worldRecovered / $worldCases) *100),2)
    [int]$worldDeaths = (Get-Cases).worldDeaths
    [float]$worldPercentageDeaths = [math]::Round((($worldDeaths / $worldCases) *100),2)

    # get individual country data
    if($Country -eq "UK"){
    
        [int]$lockdownDays = Get-DaysInLockdown

    }elseif($Country){
        [int]$cases = (Get-Cases -Country $Country).total
        [int]$newCases = (Get-Cases -Country $Country).new
        [int]$deaths = (Get-Cases -Country $Country).deaths
        [int]$recovered = (Get-Cases -Country $Country).recovered
    }   

    [int]$divisor = (Show-Chart).divisor

    [string]$casesGraph = (Show-Chart).plottedCases
    [string]$newCasesGraph = (Show-Chart).plottednewCases
    [string]$deathsGraph = (Show-Chart).plottedDeaths
    [string]$recoveredGraph = (Show-Chart).plottedRecovered

    #endregion

    
    #region write the output
    if($WindowsChart){

        [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
        [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")

        # create chart object
        $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
        $Chart.Width = 500
        $Chart.Height = 400
        $Chart.Left = 40
        $Chart.Top = 30

        # create a chartarea to draw on and add to chart
        $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
        $Chart.ChartAreas.Add($ChartArea)

        # add data to chart
        $data = @{"World Cases"=$worldCases;"New $Country Cases"=$newCases;"Total $Country Cases"=$cases; "$Country Deaths"=$deaths;"$Country Recoveries"=$recovered}
        [void]$Chart.Series.Add("Data")
        $Chart.Series["Data"].Points.DataBindXY($data.Keys, $data.Values)

        # display the chart on a form
        $Chart.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right -bor
        [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
        $Form = New-Object Windows.Forms.Form
        $Form.Text = "COVID-19 Chart"
        $Form.Width = 600
        $Form.Height = 600
        $Form.controls.add($Chart)
        $Form.Add_Shown({$Form.Activate()})
        $Form.ShowDialog()

        [void]$Chart.Titles.Add("COVID-19 Cases, deaths & recoveries")

        # change chart area colour
        $Chart.BackColor = [System.Drawing.Color]::Transparent
        


    }else{


        

        Clear-Host
        Write-Host "****************************************************" 
        Write-Host "       $Country COVID-19 Stats       " 
        Write-Host "****************************************************" 
        Write-Host
        Write-Host "World cases: $worldCases" -BackgroundColor Red
        Write-Host "World recovered cases: $worldRecovered" -BackgroundColor Green -ForegroundColor Black
        Write-Host "World % recovered: $worldPercentageRecovered%" -BackgroundColor Green -ForegroundColor Black
        Write-Host "World deaths: $worldDeaths" -BackgroundColor Black
        Write-Host "World % deaths: $worldPercentageDeaths%" -BackgroundColor Black
        Write-Host

        if($Country){

            Write-Host "Number of $Country days in lockdown: $lockdownDays" -ForegroundColor Cyan
            Write-Host "Number of $Country cases: $cases" -ForegroundColor Yellow
            Write-Host "Number of new $Country cases: $newCases" -ForegroundColor DarkCyan
            Write-Host "Number of $Country deaths: $deaths" -ForegroundColor Red
            Write-Host "Number of $Country recovered cases: $recovered" -ForegroundColor Green

            Write-Host

            Write-Host "*****  Chart scale is 1:$divisor (rounded up)      *****"
            Write-Host "$casesGraph" -ForegroundColor Yellow
            Write-Host "$newCasesGraph" -ForegroundColor DarkCyan
            Write-Host "$deathsGraph" -ForegroundColor Red 
            Write-Host "$recoveredGraph" -ForegroundColor Green
            Write-Host
        }

    
    }
    #endregion
}


Export-ModuleMember -Function Show-COVIDCases

    













