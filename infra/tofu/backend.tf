terraform {
  backend "gcs" {
    bucket = "reproducibilitron-tofu-state"
    prefix = ""
  }
}
