<#
.SYNOPSIS
Creación automatizada de Active Directory desde CSV

.AUTHOR
Yeray

.VERSION
1.1

.DATE
2026-01-11
#>

# Define los parámetros de entrada, en este caso la ruta obligatoria del archivo CSV.
param (
    [Parameter(Mandatory)]
    [string]$CsvPath
)

# Carga el módulo de Active Directory para poder usar los comandos de Windows Server.
Import-Module ActiveDirectory

# Configura la ruta del archivo log y crea la carpeta de registros si no existe.
$LogFile = "C:\Logs\AD_Deployment_$(Get-Date -Format 'yyyyMMdd_HHmm').log"
New-Item -ItemType Directory -Path (Split-Path $LogFile) -ErrorAction SilentlyContinue | Out-Null

# Función para escribir mensajes en el archivo log con marca de tiempo.
function Write-Log {
    param ($Message)
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Time - $Message" | Out-File -FilePath $LogFile -Append
}

# Función para crear Unidades Organizativas (OU) verificando que no existan previamente.
function Create-OU {
    param ($Name, $Path)

    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $Path -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $Name -Path $Path
        Write-Log "OU creada: $Name"
    } else {
        Write-Log "OU ya existe: $Name"
    }
}

# Función para crear grupos de seguridad en una ruta específica.
function Create-Group {
    param ($Name, $Path, $Scope)

    if (-not (Get-ADGroup -Filter "Name -eq '$Name'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $Name -Path $Path -GroupScope $Scope -GroupCategory Security
        Write-Log "Grupo creado: $Name"
    } else {
        Write-Log "Grupo ya existe: $Name"
    }
}

# Función para crear usuarios, activar su cuenta y asignarlos a un grupo si se especifica.
function Create-User {
    param ($User)

    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($User.SamAccountName)'" -ErrorAction SilentlyContinue)) {
        New-ADUser `
            -Name $User.Name `
            -SamAccountName $User.SamAccountName `
            -AccountPassword (ConvertTo-SecureString $User.Password -AsPlainText -Force) `
            -Enabled $true `
            -Path $User.Path

        Write-Log "Usuario creado: $($User.SamAccountName)"
    } else {
        Write-Log "Usuario ya existe: $($User.SamAccountName)"
    }

    # Asigna el usuario al grupo indicado en la columna 'Group' del CSV.
    if ($User.Group) {
        Add-ADGroupMember -Identity $User.Group -Members $User.SamAccountName -ErrorAction SilentlyContinue
        Write-Log "Usuario $($User.SamAccountName) añadido al grupo $($User.Group)"
    }
}

#Log
Write-Log "===== Inicio del despliegue AD ====="

# Importa el contenido del CSV a una variable.
$Data = Import-Csv $CsvPath

# Paso 1: Filtra y crea todas las Unidades Organizativas primero.
$Data | Where-Object { $_.Type -eq "OU" } | ForEach-Object {
    Create-OU -Name $_.Name -Path $_.Path
}

# Paso 2: Filtra y crea los grupos de seguridad necesarios.
$Data | Where-Object { $_.Type -eq "GROUP" } | ForEach-Object {
    Create-Group -Name $_.Name -Path $_.Path -Scope $_.Scope
}

# Paso 3: Filtra y crea los usuarios, vinculándolos a sus grupos.
$Data | Where-Object { $_.Type -eq "USER" } | ForEach-Object {
    Create-User -User $_
}

Write-Log "===== Fin del despliegue AD ====="