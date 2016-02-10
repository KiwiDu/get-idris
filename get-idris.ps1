﻿# A Powershell script for setting up an Idris build environment
# by Niklas Larsson <niklas@mm.st>
#
# This script is based on the corresponding script for GHC at
# https://github.com/melted/getghc.git
# For best results, run it in an empty directory.
#
# This file has been placed in the public domain by the author.

$current_dir = pwd
$msys = 64 # 32 to build a 32-bit Idris or 64 to build 64-bit

function get-tarball {
    param([string]$url, [string]$outfile, [string]$hash)
    $exists = Test-Path $outfile
    if(!$exists) {
        Invoke-WebRequest $url -OutFile $outfile -UserAgent "Curl"
        if(Test-Path $outfile) {
            Unblock-File $outfile
        } else {
            Write-Error "failed to get file $url"
            return $false
        }
    }
    $filehash = Get-FileHash $outfile -Algorithm SHA1
    if ($filehash.Hash -ne $hash) {
        rm $outfile
        $res = $filehash.Hash
        Write-Error "Mismatching hashes for $url, expected $hash, got $res"
        return $false
    } else {
        return $true
    }
}

function extract-zip
{
    param([string]$zip, [string] $outdir)
    $has_dir=Test-Path $outdir
    if(!$has_dir) {
        mkdir $outdir
    }
    if(test-path $zip)
    {
        $shell = new-object -com shell.application
        $zipdir = $shell.NameSpace($zip)
        $target = $shell.NameSpace($outdir)
        $target.CopyHere($zipdir.Items())
    }
}


function create-dir {
    param([string]$name)
    $exists = test-path $name
    if(!$exists) {
        mkdir $name
    }
}

function create-dirs {
    create-dir downloads
    create-dir support
}

function install-ghc32 {
    $url="https://www.haskell.org/ghc/dist/7.8.3/ghc-7.8.3-i386-unknown-mingw32.tar.xz"
    $file="downloads\ghc32.tar.xz"
    $hash="10ed53deddd356efcca4ad237bdd0e5a5102fb11"

    if(get-tarball $url $file $hash) {
        .\support\7za x -y $file
        .\support\7za x -y ghc32.tar -omsys
        rm ghc32.tar
    }
}

function install-msys32() {
    $url="http://sourceforge.net/projects/msys2/files/Base/i686/msys2-base-i686-20150916.tar.xz/download"
    $file="downloads\msys32.tar.xz"
    $hash="c0f87ca4e5b48d72c152305c11841551029d4257"
    if(get-tarball $url $file $hash) {
        .\support\7za x -y $file
        .\support\7za x -y msys32.tar
        mv msys32 msys
        rm msys32.tar
    }
}

function install-ghc64 {
    $url="https://www.haskell.org/ghc/dist/7.8.4/ghc-7.8.4-x86_64-unknown-mingw32.tar.xz"
    $file="downloads\ghc64.tar.xz"
    $hash="cec5b4c4fe612ac1fe9302f491ae58ac44812b26"

    if(get-tarball $url $file $hash) {
        .\support\7za x -y $file
        .\support\7za x -y ghc64.tar -omsys
        rm ghc64.tar
    }
}

function install-msys64() {
    $url="http://sourceforge.net/projects/msys2/files/Base/x86_64/msys2-base-x86_64-20150916.tar.xz/download"
    $file="downloads\msys64.tar.xz"
    $hash="abc08265b90f68e8f68c74e833f42405e85df4ee"
    if(get-tarball $url $file $hash) {
        .\support\7za x -y $file
        .\support\7za x -y msys64.tar
        mv msys64 msys
        rm msys64.tar
    }
}

function install-7zip() {
    $url="http://sourceforge.net/projects/sevenzip/files/7-Zip/9.20/7za920.zip/download"
    $file="downloads\7z.zip"
    $hash="9CE9CE89EBC070FEA5D679936F21F9DDE25FAAE0"
    if (get-tarball $url $file $hash) {
        $dir = "$current_dir\support"
        $abs_file = "$current_dir\$file"
        create-dir $dir
        Extract-Zip $abs_file $dir
    }
}

function download-cabal {
    $url=" http://www.haskell.org/cabal/release/cabal-install-1.20.0.3/cabal-1.20.0.3-i386-unknown-mingw32.tar.gz"
    $file="downloads\cabal.tar.gz"
    $hash="370590316e6433957e2673cbfda5769e4eadfd38"
    if (get-tarball $url $file $hash) {
        .\support\7za x -y $file -odownloads
        .\support\7za x -y downloads\cabal.tar -odownloads
        rm downloads\cabal.tar
    }
}

function run-msys-installscripts {
    .\msys\autorebase.bat
    .\msys\usr\bin\bash --login -c "exit" | Out-Null
     $current_posix=.\msys\usr\bin\cygpath.exe -u $current_dir
     $win_home = .\msys\usr\bin\cygpath.exe -u $HOME
     $cache_file = $HOME+"\AppData\roaming\cabal\packages\hackage.haskell.org\00-index.cache"
     if (Test-Path $cache_file) {
        Write-Host "Removing cabal cache"
        rm $cache_file
     }
     if ($msys -eq 32) {
        $ghcver="7.8.3"
     } else {
        $ghcver="7.8.4"
     }
    Write-Host "Installing packages"
    $bash_paths=@"
        mkdir -p ~/bin
        echo 'export LC_ALL=C' >> ~/.bash_profile
        echo 'export PATH=/ghc-$($ghcver)/bin:`$PATH'       >> ~/.bash_profile
        echo 'export PATH=`$HOME/bin:`$PATH'            >> ~/.bash_profile
        echo 'export PATH=$($win_home)/AppData/Roaming/cabal/bin:`$PATH' >> ~/.bash_profile
        echo 'export CC=gcc' >> ~/.bash_profile
"@
    echo $bash_paths | Out-File -Encoding ascii temp.sh
    .\msys\usr\bin\bash -l -c "$current_posix/temp.sh" | Out-Null
    # Do the installations one at a time, pacman on msys2 tends to flake out
    # for some forking reason. A new bash helps.
    .\msys\usr\bin\bash -l -c "pacman -Syu --noconfirm" | Out-Null
    .\msys\usr\bin\bash -l -c "pacman -S --noconfirm git" | Out-Null
    .\msys\usr\bin\bash -l -c "pacman -S --noconfirm tar" | Out-Null
    .\msys\usr\bin\bash -l -c "pacman -S --noconfirm gzip" | Out-Null
    .\msys\usr\bin\bash -l -c "pacman -S --noconfirm make" | Out-Null
    if ($msys -eq 32) {
        .\msys\usr\bin\bash -l -c "pacman -S --noconfirm mingw-w64-i686-gcc" | Out-Null
        .\msys\usr\bin\bash -l -c "pacman -S --noconfirm mingw-w64-i686-pkg-config" | Out-Null
        .\msys\usr\bin\bash -l -c "pacman -S --noconfirm mingw-w64-i686-libffi" | Out-Null
    } else {
        .\msys\usr\bin\bash -l -c "pacman -S --noconfirm mingw-w64-x86_64-gcc" | Out-Null
        .\msys\usr\bin\bash -l -c "pacman -S --noconfirm mingw-w64-x86_64-pkg-config" | Out-Null
        .\msys\usr\bin\bash -l -c "pacman -S --noconfirm mingw-w64-x86_64-libffi" | Out-Null
    }
    .\msys\usr\bin\bash -l -c "cp $current_posix/downloads/cabal.exe ~/bin" | Out-Null
    $ghc_cmds=@"
    cabal update
    if [ -d "idris" ]; then
        cd idris; git pull
    else
        git clone git://github.com/idris-lang/Idris-dev idris
        cd idris
    fi
    CABALFLAGS="-fffi" make
"@
    echo $ghc_cmds | Out-File -Encoding ascii build-idris.sh

    Write-Host "Getting and building Idris"
    $env:MSYSTEM="MINGW$msys"
    .\msys\usr\bin\bash -l -e -c "$current_posix/build-idris.sh" | Out-Null
}

create-dirs
echo "Getting 7-zip"
install-7zip | Out-Null
if($msys -eq 32) {
    echo "Getting msys32"
    install-msys32 | Out-Null
    echo "Getting bootstrap GHC 32-bit"
    install-ghc32 | Out-Null
} else {
    echo "Getting msys64"
    install-msys64 | Out-Null
    echo "Getting bootstrap GHC 64-bit"
    install-ghc64 | Out-Null
}
echo "Getting cabal.exe"
download-cabal | Out-Null
echo "Starting msys configuration"
run-msys-installscripts
