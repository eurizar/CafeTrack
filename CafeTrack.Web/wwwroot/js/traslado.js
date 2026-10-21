// Traslado entre bodegas. Deja en el origen solo las bodegas que tienen
// ese lote, saca del destino la bodega de origen y muestra como quedan
// las dos si se guarda asi. Quien decide es sp_trasladar_lote.
(function () {
    'use strict';

    var lote = document.getElementById('lote');
    var origen = document.getElementById('origen');
    var destino = document.getElementById('destino');
    var cantidad = document.getElementById('cantidad');
    if (!lote || !origen || !destino || !cantidad) { return; }

    var ayudaOrigen = document.getElementById('ayuda-origen');
    var ayudaDestino = document.getElementById('ayuda-destino');
    var ayudaCantidad = document.getElementById('ayuda-cantidad');
    var filaOrigen = document.getElementById('cuenta-origen');
    var filaDestino = document.getElementById('cuenta-destino');
    var nombreOrigen = document.getElementById('cuenta-origen-nombre');
    var nombreDestino = document.getElementById('cuenta-destino-nombre');
    var detalle = document.getElementById('cuenta-detalle');

    function elegida(lista) {
        return lista.options[lista.selectedIndex] || null;
    }

    function numero(op, atributo) {
        var v = op ? parseFloat(op.getAttribute(atributo)) : NaN;
        return isNaN(v) ? null : v;
    }

    function nombre(op) {
        return op ? op.textContent.split('—')[0].trim() : '';
    }

    /// En el origen solo caben las bodegas donde está ese lote.
    /// Ojo: hay una opción por lote y bodega, así que varias comparten el
    /// mismo value. Por eso siempre se elige por índice y nunca por value:
    /// asignar .value tomaba la primera coincidencia, que era de otro lote.
    function filtrarOrigen() {
        var id = lote.value;
        var quedan = [];
        var elegido = origen.options[origen.selectedIndex] || null;

        for (var i = 0; i < origen.options.length; i++) {
            var o = origen.options[i];
            if (!o.value) { continue; }

            var suyo = o.getAttribute('data-lote') === id;
            o.hidden = !suyo;
            o.disabled = !suyo;
            if (suyo) { quedan.push(o); }
        }

        if (quedan.length === 1) {
            origen.selectedIndex = quedan[0].index;
        } else if (!elegido || quedan.indexOf(elegido) === -1) {
            origen.selectedIndex = 0;
        }

        if (ayudaOrigen) {
            ayudaOrigen.textContent = !id
                ? 'Solo las bodegas que tienen ese lote.'
                : quedan.length === 1
                    ? 'Está en una sola bodega: ya quedó elegida.'
                    : 'Está en ' + quedan.length + ' bodegas; elija de cuál sale.';
        }
    }

    /// El destino nunca puede ser la bodega de la que sale.
    function filtrarDestino() {
        var desde = origen.options[origen.selectedIndex];
        var id = desde && desde.value ? desde.value : '';

        for (var i = 0; i < destino.options.length; i++) {
            var o = destino.options[i];
            if (!o.value) { continue; }

            var mismo = o.value === id;
            o.hidden = mismo;
            o.disabled = mismo;

            if (mismo && destino.selectedIndex === i) { destino.selectedIndex = 0; }
        }

        if (ayudaDestino) {
            var libre = numero(elegida(destino), 'data-libre');
            ayudaDestino.textContent = libre === null
                ? 'No puede ser la misma de donde sale.'
                : 'En esa bodega caben ' + libre.toFixed(2) + ' qq más.';
            ayudaDestino.classList.remove('ayuda-alerta');
        }
    }

    function revisar() {
        var hay = numero(elegida(origen), 'data-cantidad');
        var libre = numero(elegida(destino), 'data-libre');
        var qq = parseFloat(cantidad.value);

        if (hay === null) {
            cantidad.removeAttribute('max');
        } else {
            cantidad.max = hay;
        }

        if (ayudaCantidad) {
            if (hay === null) {
                ayudaCantidad.textContent = 'No puede superar lo que hay en el origen.';
                ayudaCantidad.classList.remove('ayuda-alerta');
            } else if (isNaN(qq) || qq <= 0) {
                ayudaCantidad.textContent = 'En el origen hay ' + hay.toFixed(2) + ' qq.';
                ayudaCantidad.classList.remove('ayuda-alerta');
            } else if (qq > hay) {
                ayudaCantidad.textContent = 'En el origen solo hay ' + hay.toFixed(2) +
                    ' qq: la base va a rechazar el traslado.';
                ayudaCantidad.classList.add('ayuda-alerta');
            } else {
                ayudaCantidad.textContent = qq === hay
                    ? 'Se mueve todo el lote de esa bodega.'
                    : 'Quedan ' + (hay - qq).toFixed(2) + ' qq en el origen.';
                ayudaCantidad.classList.remove('ayuda-alerta');
            }
        }

        // El trigger rechaza la entrada si la bodega de destino se pasa.
        if (ayudaDestino && libre !== null && !isNaN(qq) && qq > libre) {
            ayudaDestino.textContent = 'Solo caben ' + libre.toFixed(2) +
                ' qq: la bodega de destino se pasaría de su capacidad.';
            ayudaDestino.classList.add('ayuda-alerta');
        }

        pintar(hay, libre, qq);
    }

    // ------------------------------------- medidores de las dos bodegas

    var tarjetas = {};
    document.querySelectorAll('.bodega-tarjeta').forEach(function (t) {
        tarjetas[t.dataset.bodega] = t;
    });

    /// Deja cada tarjeta como está guardada hoy, sin traslado encima.
    function limpiarTarjetas() {
        Object.keys(tarjetas).forEach(function (id) {
            var t = tarjetas[id];
            pintarTarjeta(t, 0);
        });
    }

    /// Pinta una bodega con el movimiento pendiente: qq negativo si sale,
    /// positivo si entra. El tramo que cambia se marca aparte.
    function pintarTarjeta(tarjeta, movimiento) {
        var guardado = parseFloat(tarjeta.dataset.guardado);
        var capacidad = parseFloat(tarjeta.dataset.capacidad);
        var nuevo = guardado + movimiento;

        var cifra = tarjeta.querySelector('.bodega-cifra');
        var cambio = tarjeta.querySelector('.bodega-cambio');
        var libre = tarjeta.querySelector('.bodega-libre');
        var relleno = tarjeta.querySelector('.medidor-relleno');
        var fantasma = tarjeta.querySelector('.medidor-fantasma');

        if (cifra) { cifra.textContent = nuevo.toFixed(2); }

        if (cambio) {
            if (movimiento === 0) {
                cambio.hidden = true;
                cambio.textContent = '';
            } else {
                cambio.hidden = false;
                cambio.textContent = (movimiento > 0 ? '+' : '−') +
                    Math.abs(movimiento).toFixed(2) + ' qq';
                cambio.classList.toggle('entra', movimiento > 0);
                cambio.classList.toggle('sale', movimiento < 0);
            }
        }

        if (!isNaN(capacidad) && capacidad > 0) {
            if (libre) { libre.textContent = Math.max(capacidad - nuevo, 0).toFixed(2); }

            var pctViejo = Math.min(guardado / capacidad * 100, 100);
            var pctNuevo = Math.min(Math.max(nuevo, 0) / capacidad * 100, 100);
            var base = Math.min(pctViejo, pctNuevo);

            if (relleno) {
                relleno.style.width = base + '%';
                relleno.classList.toggle('alerta', pctNuevo >= 75 && pctNuevo < 90);
                relleno.classList.toggle('critico', pctNuevo >= 90);
            }

            if (fantasma) {
                var ancho = Math.abs(pctNuevo - pctViejo);
                fantasma.hidden = movimiento === 0 || ancho === 0;
                fantasma.style.left = base + '%';
                fantasma.style.width = ancho + '%';
                fantasma.classList.toggle('entra', movimiento > 0);
                fantasma.classList.toggle('sale', movimiento < 0);
            }
        }
    }

    function moverMedidores(qq) {
        limpiarTarjetas();

        if (isNaN(qq) || qq <= 0) { return; }

        var desde = origen.options[origen.selectedIndex];
        var hacia = destino.options[destino.selectedIndex];

        if (desde && desde.value && tarjetas[desde.value]) {
            pintarTarjeta(tarjetas[desde.value], -qq);
        }

        if (hacia && hacia.value && tarjetas[hacia.value]) {
            pintarTarjeta(tarjetas[hacia.value], qq);
        }
    }

    function pintar(hay, libre, qq) {
        moverMedidores(qq);

        if (!filaOrigen || !filaDestino || !detalle) { return; }

        var opOrigen = elegida(origen);
        var opDestino = elegida(destino);

        if (nombreOrigen) {
            nombreOrigen.textContent = opOrigen && opOrigen.value
                ? 'Queda en ' + nombre(opOrigen) : 'Bodega de origen';
        }

        if (nombreDestino) {
            nombreDestino.textContent = opDestino && opDestino.value
                ? 'Queda en ' + nombre(opDestino) : 'Bodega de destino';
        }

        if (hay === null || isNaN(qq) || qq <= 0 || !opDestino || !opDestino.value) {
            filaOrigen.textContent = hay === null ? '—' : hay.toFixed(2) + ' qq';
            filaDestino.textContent = '—';
            detalle.textContent = 'Elija el lote, las dos bodegas y la cantidad.';
            return;
        }

        filaOrigen.textContent = (hay - qq).toFixed(2) + ' qq del lote';
        filaDestino.textContent = qq.toFixed(2) + ' qq del lote';
        detalle.textContent = 'Se escriben dos movimientos: salida de ' + nombre(opOrigen) +
            ' y entrada en ' + nombre(opDestino) + '.';
    }

    lote.addEventListener('change', function () {
        filtrarOrigen();
        filtrarDestino();
        cantidad.value = '';
        revisar();
    });

    origen.addEventListener('change', function () {
        filtrarDestino();
        revisar();
    });

    destino.addEventListener('change', revisar);
    cantidad.addEventListener('input', revisar);

    // Al recargar, el navegador reescribe los campos: se vuelve a lo que
    // mando el servidor (en blanco al entrar, con los datos si hubo error).
    (function arrancarLimpio() {
        var form = lote.closest('form');
        if (!form) { return; }

        form.querySelectorAll('input').forEach(function (campo) {
            if (campo.type === 'hidden' || campo.readOnly) { return; }
            campo.value = campo.defaultValue;
        });

        form.querySelectorAll('select').forEach(function (lista) {
            for (var i = 0; i < lista.options.length; i++) {
                if (lista.options[i].defaultSelected) { lista.selectedIndex = i; return; }
            }
            lista.selectedIndex = 0;
        });
    })();

    filtrarOrigen();
    filtrarDestino();
    revisar();
})();
