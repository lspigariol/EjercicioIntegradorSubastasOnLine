
// Para poder testear simulando el paso del tiempo
object calendario {
	var fechaActual = new Date()
	method hoy() = fechaActual
	method pasarUnDia(){
		fechaActual = fechaActual.plusDays(1)
	}
}

object noHaySubastasCerradasDelProducto inherits Exception{}
object sinOfertas inherits Exception{}
object subastaCerrada inherits Exception{

}

object subastasOnLine {
	var subastas = []
	method subastas() = subastas

	method agregarSubasta(subasta){subastas.add(subasta)}
	
	method cerrarSubastasA(fechaCierre) {
		self.subastasACerrar(fechaCierre)
			.forEach{subasta=>
				subasta.cerrar()
			}

	}
	method subastasACerrar(fechaCierre) {
		return subastas.filter{
				s=>s.aCerrar(fechaCierre)
		}	
	}
	
	method subastasFinalizadasEnLasQueOferto(usuario) =
		subastas.filter{
			subasta=>subasta.finalizada() &&
			subasta.hayOfertaDe(usuario)
		} 

	method perdioTodas(usuario) =
		self.subastasFinalizadasEnLasQueOferto(usuario)
			.all{subasta => not usuario.esGanador(subasta)}
			
	method precioPromedio(producto){
		var subs = self.subastasCerradasDelProducto(producto)
		if (subs.isEmpty())
			throw noHaySubastasCerradasDelProducto
		return subs.sum{s=>s.mejorOferta().monto()} / subs.size()
	}
	method subastasCerradasDelProducto(producto) =
		subastas.filter{subasta => 
				subasta.cerrada() &&
				subasta.producto() == producto
			}
	method comproAnteriormente(usuario) {
		return subastas.any{subasta=>usuario.esGanador(subasta)} 
	}
}

class Usuario {
	var deuda = 0
	var antiguedad = 0
	method antiguedad(anios){antiguedad = anios}
	
	method esGanador(subasta){
		return 
			subasta.finalizada() &&
			subasta.recibioOfertas() && 
			subasta.mejorOferta().usuario() == self
	}
	method esLooser(){
		return subastasOnLine.perdioTodas(self)
	}
	method aumentarDeuda(importe) {
		deuda+=importe 
	}
	method experimentado() {
		return antiguedad >2 and subastasOnLine.comproAnteriormente(self)
	} 
}


class Oferta {
	var usuario
	var monto
	constructor(_usuario,_monto){
		usuario = _usuario
		monto = _monto
	}
	method monto() = monto
	method usuario() = usuario
}


class Subasta {
	var producto
	var base
	var fechaFinalizacion
	var vendedor
	
	const ofertas = []
	var cerrada = false
	
	constructor(_producto,_base,_fechaFinalizacion,_vendedor){
		producto = _producto
		base = _base
		fechaFinalizacion = _fechaFinalizacion
		vendedor = _vendedor
	}
	method cerrada() = cerrada
	method producto() = producto
	method ofertas() = ofertas 
	method recibirOfertaDe(usuario,monto){
		if(self.esAceptable(usuario,monto))
			ofertas.add(new Oferta(usuario,monto))
	}
	
	method finalizada() {
		return calendario.hoy() > fechaFinalizacion 
	}
	method aCerrar(fechaCierre) = fechaCierre > fechaFinalizacion && !cerrada
	method cerrar() {
		if(cerrada)
			throw subastaCerrada 
		vendedor.aumentarDeuda(self.comision())	
		cerrada = true
	}
	method comision() = producto.comisionSobre(self.mejorOferta().monto())
	
	method mejorOferta() {
		if (not self.recibioOfertas())
			throw sinOfertas
		return ofertas.last()
	}
	method hayOfertaDe(usuario) =
		self.oferentes().contains(usuario)
	
	method superaValor(monto) {
		return 
			if (self.recibioOfertas()) 
				monto > self.mejorOferta().monto()
			else
				monto > base
	}
	method recibioOfertas() = not ofertas.isEmpty()
	method oferentes() = ofertas.map{o=>o.usuario()}
	method esAceptable(usuario, monto) = 
		!self.finalizada() and self.superaValor(monto)
	
}

class SubastaEspecial inherits Subasta{
	var maximoOfertas
	
	constructor(_producto,_base,_fechaFinalizacion,_vendedor,_maximoOfertas) 
		= super(_producto,_base,_fechaFinalizacion,_vendedor){
			maximoOfertas = _maximoOfertas
		}
		
	override method esAceptable(usuario, monto) 
		= super(usuario, monto) && usuario.experimentado()
	
	override method finalizada() {
		return super() or ofertas.size() >= maximoOfertas 
	}
}

class SubastaRapida inherits Subasta{
	var montoAlcanzar
	
	constructor(_producto,_base,_fechaFinalizacion,_vendedor,_montoAlcanzar) 
		= super(_producto,_base,_fechaFinalizacion,_vendedor){
			montoAlcanzar = _montoAlcanzar
		}
		
	override method finalizada() 
		= super() or self.seAlcanzoMonto() 
	
	method seAlcanzoMonto() 
		= self.recibioOfertas()&& self.mejorOferta().monto() >= montoAlcanzar 
}


class Inmueble {
	method comisionSobre(monto) = 1000
}
class Auto{
	method comisionSobre(monto) = 500
}

class Computacion {
	method comisionSobre(monto) = monto * 0.1
}
class Articulo {
	method comisionSobre(monto) = 10.max(monto*0.5)
}