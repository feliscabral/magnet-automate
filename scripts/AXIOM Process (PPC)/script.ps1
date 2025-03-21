{
  <#
  Pre-Processed Case (PPC)
  This script allows you to select a zipped AXIOM Process Case, instead
  of an image to mimic the AXIOM Process engine. Useful for testing
  scripts and plugins against AXIOM Cases in your workflows. This will
  eliminate waiting for an image to process. Use this PowerShell script
  and rename element to, "AXIOM Process"
  #>
  
  $zip_path = "${IMAGE_PATH}"
  $out_path = "${OUTPUT_PATH}"
  
  Expand-Archive -Path $zip_path -DestinationPath $out_path -Force
}
