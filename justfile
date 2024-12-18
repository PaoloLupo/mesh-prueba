set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]

convert: analyze
    #! pvpython
    from paraview.simple import *
    name = "R1-U-000002"
    reader = LegacyVTKReader( FileNames= f"./results/{name}.vtk" )
    writer = XMLUnstructuredGridWriter()
    writer.FileName = f"./results/{name}.vtu"
    writer.UpdatePipeline()
    Delete(reader)
    Delete(writer)

analyze:
    suanpan -nu -nc -f ./script/mesh_test.sp

create:
    New-Item -ItemType Directory -Force -Path ./results | Out-Null
    New-Item -ItemType Directory -Force -Path ./script | Out-Null
    New-Item -ItemType Directory -Force -Path ./plots | Out-Null

delete:
    Remove-Item -Recurse -Force ./results
    Remove-Item -Recurse -Force ./script
    Remove-Item -Recurse -Force ./plots
