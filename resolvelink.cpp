#include <iostream>
#include <boost/filesystem.hpp>
#include <boost/optional.hpp>

namespace fs = boost::filesystem;
using fs::path;
using boost::optional;
using std::cout;
using std::cerr;

optional<path> resolve_one_component(const path &root, const path& path) {
  fs::path working_path;
  bool have_symlink = false;
  for (const fs::path& component : path) {
    if (component == "/") {
      continue;
    }
    working_path /= component;
    if (!have_symlink) {
      bool is_symlink = fs::is_symlink(root / working_path);
      if (is_symlink) {
        fs::path target = fs::read_symlink(root / working_path);
        if (target.is_absolute()) {
          working_path = target;
        } else {
          working_path.remove_filename();
          working_path /= target;
        }
        have_symlink = true;
      }
    }
  }
  return boost::make_optional(have_symlink, working_path);
}

int main(int argc, char **argv) {
  if (argc != 3) {
    cerr << "Usage: resolvelink <root> <link>\n";
    return -1;
  }
  const path root{argv[1]};
  path link{argv[2]};
  for (int i = 0; i < 100; i++) {
    if (auto resolved = resolve_one_component(root, link)) {
      link = resolved.get();
    } else {
      break;
    }
  }
  cout << link.native() << "\n";
}
