// Pide confirmacion antes de enviar los formularios marcados con
// data-confirmar. Usa el mismo <dialog> del resto del sistema.
// Sin JavaScript el formulario se envia directo: el servidor sigue
// validando, solo se pierde el paso de confirmacion.
(function () {
    'use strict';

    var dialogo = document.getElementById('dialogo-confirmar');
    var formularios = document.querySelectorAll('form[data-confirmar]');
    if (!dialogo || formularios.length === 0) { return; }

    var mensaje = document.getElementById('confirmar-mensaje');
    var aceptar = document.getElementById('confirmar-si');
    var cancelar = document.getElementById('confirmar-no');
    var pendiente = null;

    formularios.forEach(function (formulario) {
        formulario.addEventListener('submit', function (evento) {
            if (formulario.dataset.confirmado === '1') { return; }

            evento.preventDefault();
            pendiente = formulario;
            mensaje.textContent = formulario.dataset.confirmar;
            dialogo.showModal();
        });
    });

    aceptar.addEventListener('click', function () {
        dialogo.close();
        if (pendiente) {
            pendiente.dataset.confirmado = '1';
            pendiente.submit();
        }
    });

    cancelar.addEventListener('click', function () {
        dialogo.close();
        pendiente = null;
    });
})();
