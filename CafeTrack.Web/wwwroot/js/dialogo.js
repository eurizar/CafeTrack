// Convierte los <dialog data-auto> en ventanas modales: el navegador
// oscurece y desenfoca el fondo con ::backdrop.
// Sin JavaScript el dialogo ya viene con "open" y se lee como tarjeta
// dentro de la pagina, asi que el mensaje nunca se pierde.
(function () {
    'use strict';

    document.querySelectorAll('dialog[data-auto]').forEach(function (dialogo) {
        if (typeof dialogo.showModal !== 'function') { return; }

        dialogo.open = false;
        dialogo.showModal();

        // Un clic fuera de la ventana la cierra; dentro, el evento viene
        // de un hijo y no del propio <dialog>.
        dialogo.addEventListener('click', function (evento) {
            if (evento.target === dialogo) { dialogo.close(); }
        });
    });
})();
