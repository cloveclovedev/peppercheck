variable "url" {
  type    = string
  default = getenv("DATABASE_URL")
}

env "local" {
  src = [
    "file://schema/identity",
    "file://schema/profile",
    "file://schema/notification",
    "file://schema/task",
    "file://schema/matching",
    "file://schema/judgement",
    "file://schema/jobs",
    "file://schema/ops",
    "file://schema/web",
  ]
  dev = "docker://postgres/17/dev?search_path=public"
  url = var.url
  migration {
    dir = "file://migrations"
  }
  format {
    migrate {
      diff = "{{ sql . \"  \" }}"
    }
  }
}
