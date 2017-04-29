#!/usr/bin/php -f

<?php
$i = imagecreatefrompng($argv[1]);
$crop_area = array('x' => 0, 'y' => 0, 'width' => 128, 'height' => 128);
$result = imagecrop($i, $crop_area);
imagepng($result, basename($argv[1]));
