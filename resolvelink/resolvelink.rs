use std::fs;
use std::path::{Path, PathBuf, Component};

fn resolve_one_component(root: &Path, path: &Path) -> Option<PathBuf> {
    let mut working_path = PathBuf::from("/");
    let with_root = |path: &Path| {
        let mut r = root.to_path_buf();
        r.push(&path.strip_prefix("/").unwrap());
        r
    };
    let mut have_symlink = false;
    //eprintln!("working_path: {:?}", working_path);
    for component in path.components() {
        if component == Component::RootDir {
            continue;
        }
        working_path.push(component);
        //eprintln!("working_path: {:?}", working_path);
        if !have_symlink {
            //eprintln!("with root: {:?}", with_root(&working_path));
            let is_symlink = fs::symlink_metadata(with_root(&working_path))
                .map(|m| m.file_type().is_symlink())
                .unwrap_or(false);
            if is_symlink {
                // We've already checked if it's a symlink, so
                // this unwrap will only fail if it ceases to be a
                // symlink between the check and the readlink,
                // i.e. this is susceptible to a race condition. I
                // don't care enough to avoid that.
                let target = fs::read_link(with_root(&working_path)).unwrap();
                //eprintln!("target: {:?}", target);
                if target.is_absolute() {
                    //eprintln!("absolute");
                    working_path = target;
                } else {
                    working_path.pop();
                    working_path.push(target);
                    //eprintln!("relative, now {:?}", working_path);
                }
                have_symlink = true;
            }
        }
    }
    if have_symlink {
        //eprintln!("Result: {:?}", working_path);
        Some(working_path)
    } else {
        None
    }
}

fn main() {
    if std::env::args().len() != 3 {
        eprintln!("Usage: resolvelink <root> <link>");
        std::process::exit(1);
    }
    let mut it = std::env::args();
    it.next(); // skip argv[0]
    let root = PathBuf::from(it.next().unwrap());
    if !root.is_dir() {
        eprintln!("Root {} is not a directory", root.display())
    }
    let mut link = PathBuf::from(&it.next().unwrap());
    for _ in 0..100 {
        if let Some(new_link) = resolve_one_component(&root, &link) {
            link = new_link;
        } else {
            break
        }
    }
    println!("{}", link.to_str().unwrap());
}
