convert:
    #! pvpython
    from paraview.simple import *
    name = "R1-U-000002"
    reader = LegacyVTKReader( FileNames= f"./results/{name}.vtk" )
    writer = XMLUnstructuredGridWriter()
    writer.FileName = f"./results/{name}.vtu"
    writer.UpdatePipeline()
    Delete(reader)
    Delete(writer)