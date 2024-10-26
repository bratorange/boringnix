# [Boring NixOS Modules](https://boringnix.store) 
_Sane NixOS configuration defaults for different services._

This is a collection of modules a NixOS user / system administrator might want to use. They should be almost working out of the box, but still be configurable to the user's needs. Go to [boringnix.store](https://boringnix.store) to download any module.

## Contributing
You can provide a module for any service, that you use and that is not yet covered by this repository! I want to cover as many services as possible, so that users can easily use them without too much hassle. If you are unsure, whether a module is needed, feel free to open an issue or a pull request.

_Many of the aspects mentioned below are not final and will probably change, as the project evolves._
## Definitions
- `<option>`: A NixOS option.
- `<module>`: A NixOS module that configures multiple `<option>`. A `<module>` may be passed as a list member of `modules` to `nixpkgs.lib.nixosSystem` like this:
    ```nix
    nixpkgs.lib.nixosSystem {
        modules = [
            <module>
            ...
        ];
        ...
    }
    ```
  A `<module>` shall not be a NixOS module in the sense of it creating new configuration options.

## Philosophy
_Requirements for modules in order of importance:_
1. Security by default.
2. Module files shall be self-explanatory. The user shall not need to read upstream documentation to get the service running.
3. Modules shall work out of the box with minimal configuration.
4. Modules shall implement all features, that most users would expect from the service.
5. Modules shall not conflict with each other. The user shall be able to enable multiple services without having to worry about configuration conflicts.

Requirements for a module are hierarchically ordered. All requirements must be met as good as its predecessor allows it. Modules that dont meet all requirements are considered, as long as there is no better alternative and they meet requirements 1 and 2.
