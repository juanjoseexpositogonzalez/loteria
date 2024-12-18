// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract loteria is ERC20, Ownable {

    // =============================================
    // Gestión de los tokens
    // =============================================

    // Dirección del contrato NFT del proyecto
    address public nft;

    // Constructor
    constructor() ERC20("Loteria", "JA"){
        _mint(address(this), 1000);
        nft = address(new mainERC721());
    }

    // Ganador del premio de la lotería
    address public ganador;

    // Registro del usuario
    mapping(address => address) public usuario_contract;

    // Precio de los tokens ERC-20
    function precioTokens(uint256 _numTokens) internal pure returns (uint256){
        return _numTokens * (1 ether);
    }

    // Visualización del balance de tokens ERC-20 de un usuario
    function balanceTokens(address _account) public view returns (uint256){
        return balanceOf(_account);
    }

        // Visualización del balance de tokens ERC-20 del Smart Contract
    function balanceTokensSC() public view returns (uint256){
        return balanceOf(address(this));
    }

    // Visualización de ethers del Smart Contract
    // 1 ether -> 10^18 Gweis
    function balanceEthersSC() public view returns (uint256){
        return address(this).balance / 10**18;
    }

    // Generación de nuevos tokens ERC-20
    function mint(uint256 _cantidad) public onlyOwner {
        _mint(address(this), _cantidad);
    }

    // Registro de usuarios
    function registrar() internal {
        address addr_personal_contract = address(new boletosNFTs(msg.sender, address(this), nft));
        usuario_contract[msg.sender] = addr_personal_contract;
    }

    // Información de un usuario
    function usersInfo(address _account) public view returns (address){
        return usuario_contract[_account];
    }

    // Compra de tokens ERC-20
    function compraTokens(uint256 _numTokens) public payable {

        // Registro del usuario
        if(usuario_contract[msg.sender] == address(0)) {
            registrar();
        }

        // Establecimiento del coste de los tokens a comprar
        uint256 coste = precioTokens(_numTokens);
        // Evaluación del dinero que el cliente paga por los tokens
        require(msg.value >= coste, "Compra menos tokens o paga con mas ethers"); 

        // Obtención del número de tokens ERC-20 disponibles
        uint256 balance = balanceTokensSC();
        require(_numTokens <= balance, "Compra un numero menor de tokens");

        // Devolución del dinero sobrante
        uint256 returnValue = msg.value - coste;

        // El Smart Contract devuelve la cantidad restante
        payable(msg.sender).transfer(returnValue);

        // Envío de los tokens al cliente/usuario_contract
        _transfer(address(this), msg.sender, _numTokens);
    }

    // Devolución de tokens al Smart Contract
    function devolverTokens(uint _numTokens) public payable {
        // El número de tokens debe ser mayor a cero
        require(_numTokens > 0, "Necesitas devolver un numero de tokens mayor a cero");
        // El usuario debe acreditar tener los tokens que quiere devolver
        require(_numTokens <= balanceTokens(msg.sender), "No tienes los tokens que deseas devolver");

        // El usuario transfiere los tokens al Smart Contract
        _transfer(msg.sender, address(this), _numTokens);

        // El Smart Contract envía los ethers al usuario
        payable(msg.sender).transfer(precioTokens(_numTokens));
    }


    // =============================================
    // Gestión de la lotería
    // =============================================


    // Precio del boleto de lotería (en tokens ERC-20)
    uint public precioBoleto = 5;

    // Relación: persona que compra boletos -> el número de boletos
    mapping(address => uint[]) idPersona_boletos;
    // Relación: boleto -> ganador
    mapping(uint => address) ADNBoleto;
    // Numero aleatorio
    uint randNonce = 0;
    // Boletos de la lotería generados
    uint[] boletosComprados;


    // Compra de boletos de lotería
    function compraBoleto(uint _numBoletos) public {
        // Precio total de los boletos a comprar
        uint precioTotal = _numBoletos * precioBoleto;
        // Verificación de los tokens del usuario
        require(precioTotal <= balanceTokens(msg.sender), "No tienes tokens suficientes");
        // Transferencia de tokens del usuario al Smart Contract
        _transfer(msg.sender, address(this), precioTotal);

        /* Recoge la marca de tiempo (block.timestamp), msg.sender y un Nonce
           (un número que sólo se utiliza una vez, para que no ejecutemos dos veces la misma
           función de hash con los mismos parámetros de entrada) en incremento.
           Se utiliza 'keccak256' para convertir estas entradas a un hash aleatorio,
           convertir ese hash a un uint y luego utilizamos el módulo (100_000 en este caso) para tomar 
           los últimos 5 dígitos, dando un valor aleatorio entre 0 - 99_999 */
        for (uint i=0; i< _numBoletos; i++) {
            uint random = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % 100_000;
            randNonce += 1;
            // Almacenameinto de los datos del boleto enlazados al usuario
            idPersona_boletos[msg.sender].push(random);
            // Almacenamiento de los datos de los boletos
            boletosComprados.push(random);
            // Asignación del ADN del boleto para la generación de un ganador
            ADNBoleto[random] = msg.sender;
            // Creación de un nuevo NFT para el número de boleto
            boletosNFTs(usuario_contract[msg.sender]).mintBoleto(msg.sender, random);
        }
    }


    // Visualización de los boletos del usuario
    function tusBoletos(address _propietario) public view returns (uint[] memory){
        return idPersona_boletos[_propietario];
    }

    // Generación del ganador de la lotería
    function generarGanador() public onlyOwner {
        // Declaración de la longitud del array
        uint longitud = boletosComprados.length;
        // Verificación de la compra de al menos 1 boleto
        require(longitud > 0, "No hay boletos comprados");

        // Elección aleatoria de un número entre [0-Longitud]
        uint random = uint(uint(keccak256(abi.encodePacked(block.timestamp))) % longitud);

        // Selección del número aleatorio
        uint eleccion = boletosComprados[random];

        // Dirección del ganador de la lotería
        ganador = ADNBoleto[eleccion];

        // Envío del 95% del premio de lotería al ganador
        payable(ganador).transfer(address(this).balance * 95 /100);
        // Envío del 5% del premio al owner
        payable(owner()).transfer(address(this).balance * 5 /100);

    }


}

// Smart Contract de NFTs
contract mainERC721 is ERC721 {

    address public direccionLoteria;

    constructor() ERC721("Loteria", "STE"){
        direccionLoteria = msg.sender;
    }

    // Creación de NFTs
    function safeMint(address _propietario, uint256 _boleto) public {
        require(msg.sender == loteria(direccionLoteria).usersInfo(_propietario),
                "No tienes permisos para ejecutar esta funcion");
        _safeMint(_propietario, _boleto);
    }
    // 

}


contract boletosNFTs {

    // Datos relevantes del propietario
    struct Owner{
        address direccionPropietario;
        address contratoPadre;
        address contratoNFT;
        address contratoUsuario;
    }

    // Estructura de datos de tipo Owner
    Owner public propietario;

    // Constructor del Smart Contract (hijo)
    constructor(address _propietario, address _contratoPadre, address _contratoNFT) {
        propietario = Owner(_propietario,
                            _contratoPadre,
                            _contratoNFT,
                            address(this));
    }

    // Conversión de los números de boletos de lotería
    function mintBoleto(address _propietario, uint256 _boleto) public {
        require(msg.sender == propietario.contratoPadre,
                "No tienes permisos para ejecutar esta funcion");
        mainERC721(propietario.contratoNFT).safeMint(_propietario, _boleto);
    }

}