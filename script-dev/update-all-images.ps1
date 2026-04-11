# update-all-images.ps1
param(
    [string]$DOCKER_USER = "bradlu4"
)

# 用日期做 Tag (取尾 6 碼)
$TAG = (Get-Date -Format "yyMMdd")
Write-Host "[INFO] Using tag: $TAG"

# 要 build 的 image 清單
$images = @(
    @{ Name = "ub1604-quecopen-asr1806sdk-img"; Dockerfile = "dockerfile-quecopen-asr1806-sdk" },
    @{ Name = "ub1804-quecopen-x7xsdk-img";     Dockerfile = "dockerfile-quecopen-sdx7x" },
    @{ Name = "ub1804-quecopen-x6xsdk-img";     Dockerfile = "dockerfile-quecopen-sdx6x-sdk" },
    @{ Name = "ub1804-quecopen-x35sdk-img";     Dockerfile = "dockerfile-quecopen-sdx35-sdk" },
    @{ Name = "ub2204-quecopen-t830sdk-img";    Dockerfile = "dockerfile-quecopen-t830-sdk-ub2204" },
    @{ Name = "ub1804-quecopen-t830sdk-img";    Dockerfile = "dockerfile-quecopen-t830-sdk-ub1804" }
)

foreach ($img in $images) {
    $name = $img.Name
    $dockerfile = $img.Dockerfile
    $fullTag = "$DOCKER_USER/${name}:$TAG"

    Write-Host "============================================"
    Write-Host "[INFO] Building $name from $dockerfile"

    # 注意 build context 與 Dockerfile 都在同一層
    docker build -t "${name}:latest" -f "./$dockerfile" "."

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Build failed for ${name}"
        exit 1
    }

    docker tag "${name}:latest" $fullTag

    Write-Host "[INFO] Pushing $fullTag"
    docker push $fullTag
}
