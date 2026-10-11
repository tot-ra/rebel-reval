"""Reconstruct a closed surface from new sculpt points (Open3D 0.19 / Python 3.10).

This offline build step uses oriented points exported from the freshly generated
sculpt after backdrop removal. No existing-character geometry is an input.
"""
import argparse
from pathlib import Path
import open3d as o3d
import numpy as np


def main():
    parser=argparse.ArgumentParser();parser.add_argument('points',type=Path);parser.add_argument('output',type=Path);args=parser.parse_args()
    points=o3d.io.read_point_cloud(str(args.points));assert points.has_normals()
    mesh,density=o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(points,depth=8,scale=1.1,linear_fit=False,n_threads=8)
    labels,counts,areas=mesh.cluster_connected_triangles();labels=np.asarray(labels)
    mesh.remove_triangles_by_mask(labels!=int(np.argmax(areas)));mesh.remove_unreferenced_vertices()
    mesh=mesh.simplify_quadric_decimation(52000);mesh.compute_vertex_normals()
    assert len(mesh.triangles)>10000
    o3d.io.write_triangle_mesh(str(args.output),mesh,write_ascii=False)
    print({'vertices':len(mesh.vertices),'triangles':len(mesh.triangles),'watertight':mesh.is_watertight(),'edge_manifold':mesh.is_edge_manifold()})


if __name__=='__main__':main()
