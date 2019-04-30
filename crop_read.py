import cv2
from glob import glob

root_path = "/home/a/Downloads/seq_smith_alligned1.klg-export"

for i in range(len(glob(root_path + "/rgb/rgb*.png"))):
    rgb = cv2.imread(root_path + "/rgb/rgb" + str(i) +".png")
    view = cv2.imread(root_path + "/view/view" + str(i) +".png")
    cv2.imshow("rgb", rgb)
    cv2.imshow("view", view[480:960, 960:1600])
    cv2.waitKey(0)
