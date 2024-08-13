import xml.etree.ElementTree as ET
import time
from datetime import timedelta
import os.path
import sys

    
def split_list(in_list, n):
    #Create a list of lists of length n.
    
    new_list = []
    for i in range(0, len(in_list), n):
        new_list.append(in_list[i:i+n])
        
    return new_list

    
def distance(x1, y1, z1, x2, y2, z2, x_res, y_res, z_res):
    #Calculate distance for filter function.
    #Take into account resolution of x, y, and z pixels for calculation
    x1 *= x_res
    x2 *= x_res
    y1 *= y_res
    y2 *= y_res
    z1 *= z_res
    z2 *= z_res    
    
    return ((x2 - x1)**2 + (y2 - y1)**2 + (z2 - z1)**2)**0.5


def new(x, y, z, filter_size, x_res, y_res, z_res):
    #Iterate through list of empty lists and run filter function.
    
    new_x = [[] for p in range(len(x))]
    new_y = [[] for p in range(len(y))]
    new_z = [[] for p in range(len(z))]
    
    for p in range(len(x)):
        new_x[p], new_y[p], new_z[p] = filter(x[p], y[p], z[p], new_x[p], new_y[p], new_z[p], filter_size,
        x_res, y_res, z_res)
        
    return new_x, new_y, new_z
    
    
def filter(x, y, z, new_x, new_y, new_z, filter_size, x_res, y_res, z_res):
    #Zip through list of points and add to new filtered list if it isn't
    #within a distance d of any other points within filtered lists.
    
    for i, j, k in zip(x, y, z):
        add = True
        for l, m, n in zip(new_x, new_y, new_z):
            if distance(i, j, k, l, m, n, x_res, y_res, z_res) < filter_size:
                add = False
                break
            else:
                continue
            break
            
        if add:
            new_x.append(i)
            new_y.append(j)
            new_z.append(k)
            
    return new_x, new_y, new_z
         
         
def point(x, y, z, filter_size, filename):
    #Write new lists from filter function into new file.
    
    output_file_destination, output_filename = get_output_file(filename)
    output_filename = os.path.join(output_file_destination, output_filename)
    try:
        xml = open(output_filename, 'w')
    except:
        print('Error in finding directory.')
        
    xml.write('<?xml version="1.0" encoding="UTF-8"?>' + "\n")
    xml.write('<CellCounter_Marker_File>' + "\n")
    xml.write('  <Image_Properties>' + "\n")
    xml.write('    <Image_Filename>placeholder.tif</Image_Filename>' + "\n")
    xml.write('  </Image_Properties>' + "\n")
    xml.write('  <Marker_Data>' + "\n")
    xml.write('    <Current_Type>1</Current_Type>' + "\n")
    xml.write('    <Marker_Type>' + "\n")
    xml.write('      <Type>1</Type>' + "\n")
    
    for p in range(len(x)):
        for i, j, k in zip(x[p], y[p], z[p]):
            xml.write('      <Marker>' + "\n")
            xml.write('        <MarkerX>' + str(i) + '</MarkerX>' + "\n")
            xml.write('        <MarkerY>' + str(j) + '</MarkerY>' + "\n")
            xml.write('        <MarkerZ>' + str(k) + '</MarkerZ>' + "\n")
            xml.write('      </Marker>' + "\n")
    xml.write('    </Marker_Type>' + "\n")
    xml.write('  </Marker_Data>' + "\n")
    xml.write('</CellCounter_Marker_File>')
    
    return


def get_output_file(filename):

    output_file_destination = filename.split('/cells.xml')[0]
    output_filename = 'cells' + '.xml'
    
    return output_file_destination, output_filename
    

for arg in sys.argv[1:]:
    
    try:
        name, value = arg.split('=',1)
    
    except:
        print("Error parsing.")
        
    if name.lower() == "--file":
        filename = value
        
    elif name.lower() == "--filter":
        filter_size = value
        
    elif name.lower() == "--cellsplits":
        cells_per_split = value
        
    elif name.lower() == "--output_destination":
        output_file_destination = value
        
    elif name.lower() == "--x_res":
        x_res = value
        
    elif name.lower() == "--y_res":
        y_res = value
        
    elif name.lower() == "--z_res":
        z_res = value
        
output_filename = get_output_file(filename)


tree = ET.parse(filename)
root = tree.getroot()
a = root.find('Marker_Data')
b = a.find('Marker_Type')

x_points = []
y_points = []
z_points = []

for i in b.findall('Marker'):
    x = int(i.find('MarkerX').text)
    y = int(i.find('MarkerY').text)
    z = int(i.find('MarkerZ').text)
    x_points.append(x)
    y_points.append(y)
    z_points.append(z)
    
start = time.time()

x_points = split_list(x_points, int(cells_per_split))
y_points = split_list(y_points, int(cells_per_split))
z_points = split_list(z_points, int(cells_per_split))



x, y, z = new(x_points, y_points, z_points, int(filter_size), float(x_res), float(y_res), float(z_res))

print("Writing new file...")


point(x, y, z, filter_size, filename)


count_x_points = 0
for i in x_points:
    for j in i:
        count_x_points += 1
             
count_x = 0
for i in x:
    for j in i:
        count_x += 1
            
filtered = count_x_points - count_x


print("Complete. {} points filtered in {}.".format(filtered, timedelta(seconds=time.time() - start)))


